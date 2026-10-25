# Tears down router.amneziawg + router.splittunnel (wg0 + RU-ipset policy
# routing), replaced by router.xray + router.singbox. Same idea as
# salt/tachiproxy/proxyroute.sls's teardown of its own splittunnel copy.
# Runs FIRST, before xray/sing-box are even installed: with pref 200
# pointing at a dead wg0 (no handshake), router-1 can't reach github.com /
# sing-box.app to download them at all -- plain WAN is strictly better
# than a black-holed tunnel.
# The amneziawg DKMS module / awg tools built under /usr/local/src are
# left installed -- inert without wg0.conf.

{%- set st = pillar.get('router', {}).get('splittunnel', {}) %}

awg_teardown_split_tunnel_dead:
  service.dead:
    - name: split-tunnel
    - enable: False

awg_teardown_wg0_dead:
  service.dead:
    - name: awg-quick@wg0
    - enable: False
    - require:
      - service: awg_teardown_split_tunnel_dead

# split-tunnel.sh's ip rules / ipset / mangle chains / NAT rule / resolved
# overrides have no uninstall path of their own (the unit has no
# ExecStop). netfilter-persistent's rules.v4 (router.nat) may have been
# saved while SPLIT_* were live, so re-save once they're gone or a reboot
# restores them.
awg_teardown_routing:
  cmd.run:
    - name: |
        for pref in 40 41 45 46 50 100 200; do
          ip rule del pref "$pref" 2>/dev/null || true
        done
        ip route flush table vpn 2>/dev/null || true
        {%- if st.get('wg_endpoint_ip') %}
        ip route del {{ st['wg_endpoint_ip'] }}/32 2>/dev/null || true
        {%- endif %}
        iptables -t mangle -D OUTPUT -j SPLIT_OUT 2>/dev/null || true
        iptables -t mangle -D PREROUTING -j SPLIT_PRE 2>/dev/null || true
        iptables -t mangle -F SPLIT_OUT 2>/dev/null || true
        iptables -t mangle -X SPLIT_OUT 2>/dev/null || true
        iptables -t mangle -F SPLIT_PRE 2>/dev/null || true
        iptables -t mangle -X SPLIT_PRE 2>/dev/null || true
        iptables -t mangle -D PREROUTING -s 172.16.0.0/12 -m set --match-set ru dst -j MARK --set-mark 0x1 2>/dev/null || true
        iptables -t mangle -D PREROUTING -s 172.16.0.0/12 -m set --match-set ru dst -j CONNMARK --save-mark 2>/dev/null || true
        {%- if st.get('wan_if') %}
        iptables -t mangle -D PREROUTING -i {{ st['wan_if'] }} -j CONNMARK --set-mark 0x1 2>/dev/null || true
        iptables -t nat -D POSTROUTING -m mark --mark 0x1 -o {{ st['wan_if'] }} -j MASQUERADE 2>/dev/null || true
        resolvectl revert {{ st['wan_if'] }} 2>/dev/null || true
        {%- endif %}
        iptables -t mangle -D OUTPUT -m connmark --mark 0x1 -j MARK --set-mark 0x1 2>/dev/null || true
        iptables -t mangle -D PREROUTING -m conntrack --ctstate RELATED,ESTABLISHED -j CONNMARK --restore-mark 2>/dev/null || true
        iptables -t mangle -D FORWARD -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
        ipset destroy ru 2>/dev/null || true
        systemctl restart systemd-resolved || true
        ip route flush cache
        if command -v netfilter-persistent >/dev/null 2>&1; then
          netfilter-persistent save
        fi
    - onlyif: >-
        ip rule list pref 200 | grep -q . ||
        iptables -t mangle -S SPLIT_PRE >/dev/null 2>&1 ||
        iptables -t mangle -C FORWARD -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null ||
        ipset list ru >/dev/null 2>&1
    - require:
      - service: awg_teardown_wg0_dead

awg_teardown_files_absent:
  file.absent:
    - names:
      - /etc/systemd/system/split-tunnel.service
      - /opt/splittunnel
      # Holds the AWG client private key.
      - /etc/amnezia/amneziawg/wg0.conf
    - require:
      - cmd: awg_teardown_routing

awg_teardown_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: awg_teardown_files_absent
