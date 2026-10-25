#!py
# Generates router-1's xray client.json and sing-box config.json from
# pillar router:xray / router:singbox. Python renderer rather than Jinja
# because the source of truth is a single vless:// share URL, same as
# setup-xray-singbox.sh takes -- the parsing below is that script's
# embedded Python, adapted to read pillar instead of argv and to emit
# file.managed states instead of writing the files directly.
#
# Differences from setup-xray-singbox.sh, both because router-1 is a
# router (forwards hashibr's traffic, runs unbound) rather than a leaf box:
# - The direct CIDRs (LAN/private ranges, the VLESS server itself) go into
#   the tun's route_exclude_address, not just a route rule -- excluded
#   destinations never enter tun0 at all, so forwarded hashibr<->LAN
#   traffic and the Salt control channel stay plain kernel-routed instead
#   of being terminated and re-dialed by sing-box.
# - No hijack-dns rule: unbound's own upstream queries would get hijacked
#   into sing-box's resolver, which (with no dns block) falls back to the
#   system resolver -- i.e. unbound again. UDP DNS just goes direct like
#   the rest of UDP (xray's SOCKS inbound has udp off).

import json
from urllib.parse import urlparse, parse_qs, unquote

from salt.exceptions import SaltRenderError

PRIVATE_CIDRS = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "100.64.0.0/10",
    "169.254.0.0/16",
]


def _one(qs, key, default=""):
    value = qs.get(key, [default])
    return value[0] if value else default


def _xray_config(url, force_port, socks_port):
    p = urlparse(url.strip())
    qs = parse_qs(p.query)

    if p.scheme != "vless":
        raise SaltRenderError("pillar router:xray:vless_url must start with vless://")

    uuid = p.username
    server = p.hostname
    if not uuid or not server:
        raise SaltRenderError("pillar router:xray:vless_url is missing the UUID or server")

    pbk = _one(qs, "pbk", _one(qs, "publicKey", ""))
    if not pbk:
        raise SaltRenderError("pillar router:xray:vless_url is missing pbk/publicKey")

    user = {"id": uuid, "encryption": "none"}
    flow = _one(qs, "flow", "")
    if flow:
        user["flow"] = flow

    reality = {
        "serverName": _one(qs, "sni", _one(qs, "serverName", server)),
        "fingerprint": _one(qs, "fp", _one(qs, "fingerprint", "chrome")),
        "publicKey": pbk,
        "shortId": _one(qs, "sid", _one(qs, "shortId", "")),
    }
    spx = unquote(_one(qs, "spx", _one(qs, "spiderX", "")))
    if spx:
        reality["spiderX"] = spx

    return {
        "log": {"loglevel": "info"},
        "inbounds": [
            {
                "tag": "socks-in",
                "port": socks_port,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "settings": {"udp": False, "auth": "noauth"},
            }
        ],
        "outbounds": [
            {
                "tag": "proxy",
                "protocol": "vless",
                "settings": {
                    "vnext": [
                        {
                            "address": server,
                            # setup-xray-singbox.sh's FORCE_PORT: the share
                            # URL's port is ignored in favour of this.
                            "port": force_port,
                            "users": [user],
                        }
                    ]
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": reality,
                },
            }
        ],
    }


def _singbox_config(sb, server_ip, socks_port):
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
        rules.append({"network": "udp", "outbound": "direct"})
        route["final"] = "proxy"
    else:
        rules.append({"ip_cidr": proxy_cidrs, "outbound": "proxy"})
        rules.append({"network": "udp", "outbound": "direct"})
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
            {
                "type": "socks",
                "tag": "proxy",
                "server": "127.0.0.1",
                "server_port": socks_port,
            },
            {"type": "direct", "tag": "direct"},
        ],
        "route": route,
    }


def _dump(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def run():
    router = __pillar__.get("router", {})
    xr = router.get("xray", {})
    sb = router.get("singbox", {})

    url = xr.get("vless_url", "")
    server_ip = xr.get("server_ip", "")
    if not url or not server_ip:
        # Fail the render outright rather than half-apply: router.singbox
        # tears down the AWG tunnel, which must not happen without a
        # working replacement configured.
        raise SaltRenderError("pillar router:xray:vless_url and router:xray:server_ip are required")

    socks_port = int(xr.get("socks_port", 1080))
    force_port = int(xr.get("force_port", 443))

    return {
        "include": ["router.xray", "router.singbox"],
        "xray_client_config": {
            "file.managed": [
                {"name": "/usr/local/etc/xray/client.json"},
                {"contents": _dump(_xray_config(url, force_port, socks_port))},
                {"mode": "0600"},
                # check_cmd appends the candidate file's (extensionless)
                # temp path, hence the explicit -format.
                {"check_cmd": "/usr/local/bin/xray run -test -format json -config"},
                {"require": [{"cmd": "xray_install"}, {"file": "xray_config_dir"}]},
            ]
        },
        "singbox_config": {
            "file.managed": [
                {"name": "/etc/sing-box/config.json"},
                {"contents": _dump(_singbox_config(sb, server_ip, socks_port))},
                {"mode": "0600"},
                {"check_cmd": "/usr/bin/sing-box check -c"},
                {"require": [{"cmd": "singbox_install"}, {"file": "singbox_config_dir"}]},
            ]
        },
    }
