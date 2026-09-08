# Static /32 routes for epr.elastic.co and elastic.co via the hashibr NIC
# (proxmox-terraform/vm-elk.tf's second network_device) instead of vm-elk's
# normal vmbr0 egress -- router-1's split-tunnel.sh already sends anything
# routed through it out via the AmneziaWG tunnel by default (see
# pillar/router.sls's splittunnel comment re: the HashiCorp CDN geo-block --
# same class of problem, same fix), and its nat.sls masquerades the whole
# 10.30.30.0/24 subnet regardless of destination -- so nothing on router-1
# needs to change; this state is entirely local to vm-elk.
#
# Both hostnames are CDN-backed with no fixed IP range, so the route script
# resolves them itself at boot (via the system resolver -- no DNS hijack
# needed) and adds a static route per result. Replaces an earlier
# ipset+dnsmasq+fwmark policy-routing approach that routed every packet by
# destination; a plain per-IP route is simpler and sufficient here, at the
# cost of needing a restart if the CDN ever rotates onto IPs not seen at
# the last boot.

# --- Tear down the earlier ipset+dnsmasq+fwmark approach this replaces ---

# dnsmasq was hijacking all of vm-elk's DNS (via the resolved.conf.d
# override below) to see queries for the ipset -- that override has to go
# first, or resolution breaks the moment dnsmasq itself stops.
elastic_hashibr_resolved_conf_absent:
  file.absent:
    - name: /etc/systemd/resolved.conf.d/elastic-hashibr.conf

elastic_hashibr_resolved_restart_cleanup:
  cmd.run:
    - name: systemctl restart systemd-resolved
    - onchanges:
      - file: elastic_hashibr_resolved_conf_absent

elastic_hashibr_dnsmasq_disabled:
  service.dead:
    - name: dnsmasq
    - enable: False
    - require:
      - cmd: elastic_hashibr_resolved_restart_cleanup

elastic_hashibr_dnsmasq_conf_absent:
  file.absent:
    - name: /etc/dnsmasq.d/elastic-hashibr.conf
    - require:
      - service: elastic_hashibr_dnsmasq_disabled

elastic_hashibr_ipset_service_disabled:
  service.dead:
    - name: elk-hashibr-ipset
    - enable: False

elastic_hashibr_ipset_unit_absent:
  file.absent:
    - name: /etc/systemd/system/elk-hashibr-ipset.service
    - require:
      - service: elastic_hashibr_ipset_service_disabled

elastic_hashibr_mangle_rule_absent:
  cmd.run:
    - name: iptables -t mangle -D OUTPUT -m set --match-set elk-hashibr dst -j MARK --set-mark 0x1
    - onlyif: iptables -t mangle -C OUTPUT -m set --match-set elk-hashibr dst -j MARK --set-mark 0x1

elastic_hashibr_ipset_absent:
  cmd.run:
    - name: ipset destroy elk-hashibr
    - onlyif: ipset list elk-hashibr
    - require:
      - cmd: elastic_hashibr_mangle_rule_absent

elastic_hashibr_policy_rule_absent:
  cmd.run:
    - name: ip rule del pref 201
    - onlyif: ip rule show | grep -q '^201:'

elastic_hashibr_policy_table_absent:
  cmd.run:
    - name: ip route flush table hashibr-elastic
    - onlyif: ip route show table hashibr-elastic | grep -q .

# --- New: plain static routes ---

elastic_hashibr_route_script:
  file.managed:
    - name: /usr/local/sbin/elastic-hashibr-route.sh
    - mode: '0755'
    - contents: |
        #!/usr/bin/env bash
        set -euo pipefail

        # Resolved at run time rather than hardcoded as e.g. "eth1" -- this
        # is DHCP-assigned by router-1 (salt/router/dhcp.sls), so the
        # gateway is always 10.30.30.1, but nothing guarantees which guest
        # interface name Proxmox/cloud-init hand the hashibr NIC (see
        # salt/elk/disk.sls's data-disk detection for the same lesson).
        IFACE=$(ip -4 -o addr show | awk '$4 ~ "^10\\.30\\.30\\." { print $2; exit }')
        if [ -z "$IFACE" ]; then
          echo "no interface with a 10.30.30.0/24 address found" >&2
          exit 1
        fi
        GATEWAY="10.30.30.1"

        for host in epr.elastic.co elastic.co; do
          for ip in $(getent ahostsv4 "$host" | awk '{ print $1 }' | sort -u); do
            ip route replace "${ip}/32" via "$GATEWAY" dev "$IFACE"
          done
        done

elastic_hashibr_route_service:
  file.managed:
    - name: /etc/systemd/system/elastic-hashibr-route.service
    - contents: |
        [Unit]
        Description=Static routes for epr.elastic.co/elastic.co via hashibr
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=oneshot
        ExecStart=/usr/local/sbin/elastic-hashibr-route.sh
        RemainAfterExit=true

        [Install]
        WantedBy=multi-user.target
    - require:
      - file: elastic_hashibr_route_script

elastic_hashibr_route_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: elastic_hashibr_route_service

elastic_hashibr_route_running:
  service.running:
    - name: elastic-hashibr-route
    - enable: True
    - require:
      - file: elastic_hashibr_route_service
      - cmd: elastic_hashibr_route_reload
    - watch:
      - file: elastic_hashibr_route_script
