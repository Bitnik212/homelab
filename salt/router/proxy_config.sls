#!py
# Generates router-1's sing-box config.json from pillar router:amneziawg /
# router:singbox. Started as setup-xray-singbox.sh's embedded Python,
# adapted to read pillar instead of argv and to emit a file.managed state
# instead of writing the file directly.
#
# Differences from setup-xray-singbox.sh, both because router-1 is a
# router (forwards hashibr's traffic, runs unbound) rather than a leaf box:
# - The direct CIDRs (LAN/private ranges, the AWG server itself) go into
#   the tun's route_exclude_address, not just a route rule -- excluded
#   destinations never enter tun0 at all, so forwarded hashibr<->LAN
#   traffic and the Salt control channel stay plain kernel-routed instead
#   of being terminated and re-dialed by sing-box.
# - No hijack-dns rule: unbound's own upstream queries would get hijacked
#   into sing-box's resolver, which (with no dns block) falls back to the
#   system resolver -- i.e. unbound again. UDP DNS just goes through the
#   tunnel like the rest of UDP.

import ipaddress
import json

from salt.exceptions import SaltRenderError

PRIVATE_CIDRS = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "100.64.0.0/10",
    "169.254.0.0/16",
]

WG_IF = "wg0"


def _endpoint_ip(endpoint):
    # A hostname can't go into route_exclude_address, and leaving the
    # endpoint out of it would loop wg0's own packets back into tun0.
    host = endpoint.rpartition(":")[0]
    try:
        return str(ipaddress.IPv4Address(host))
    except ValueError:
        raise SaltRenderError("pillar router:amneziawg:endpoint must be IPv4:port")


def _singbox_config(sb, server_ip):
    mode = sb.get("mode", "full")
    if mode not in ("full", "selected"):
        raise SaltRenderError("pillar router:singbox:mode must be full or selected")

    proxy_cidrs = list(sb.get("proxy_cidrs", []))
    if mode == "selected" and not proxy_cidrs:
        raise SaltRenderError("pillar router:singbox:mode=selected requires proxy_cidrs")

    direct_cidrs = ["{}/32".format(server_ip)]
    if sb.get("ssh_client_ip"):
        direct_cidrs.append("{}/32".format(sb["ssh_client_ip"]))
    direct_cidrs += PRIVATE_CIDRS

    rules = [{"action": "sniff"}]
    route = {"auto_detect_interface": True, "rules": rules}

    if mode == "full":
        rules.append({"ip_cidr": direct_cidrs, "outbound": "direct"})
        if sb.get("direct_ru", True):
            route["rule_set"] = [
                {
                    "tag": "geoip-ru",
                    "type": "remote",
                    "format": "binary",
                    "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs",
                    "download_detour": "direct",
                }
            ]
            rules.append({"rule_set": "geoip-ru", "outbound": "direct"})
        route["final"] = "proxy"
    else:
        rules.append({"ip_cidr": proxy_cidrs, "outbound": "proxy"})
        route["final"] = "direct"

    return {
        "log": {"level": "info"},
        "inbounds": [
            {
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "tun0",
                "address": ["198.18.0.1/30"],
                "auto_route": True,
                "strict_route": True,
                "route_exclude_address": direct_cidrs,
                "stack": "gvisor",
            }
        ],
        "outbounds": [
            {"type": "direct", "tag": "proxy", "bind_interface": WG_IF},
            {"type": "direct", "tag": "direct"},
        ],
        "route": route,
    }


def _dump(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def run():
    router = __pillar__.get("router", {})
    awg = router.get("amneziawg", {})
    sb = router.get("singbox", {})

    endpoint = awg.get("endpoint", "")
    if not endpoint:
        # Fail the render outright rather than half-apply: sing-box must not
        # get pointed at a wg0 that was never configured.
        raise SaltRenderError("pillar router:amneziawg:endpoint is required")

    return {
        "include": ["router.singbox"],
        "singbox_config": {
            "file.managed": [
                {"name": "/etc/sing-box/config.json"},
                {"contents": _dump(_singbox_config(sb, _endpoint_ip(endpoint)))},
                {"mode": "0600"},
                {"check_cmd": "/usr/bin/sing-box check -c"},
                {"require": [{"cmd": "singbox_install"}, {"file": "singbox_config_dir"}]},
            ]
        },
    }
