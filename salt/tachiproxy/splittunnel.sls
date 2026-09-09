# Policy routing for wg0 (salt/tachiproxy/amneziawg.sls, Table = off) --
# same table/ip-rule shape as router.splittunnel, scoped down to just this
# box's needs (no RU-ipset split, no WAN-facing SSH safety rule: this VM
# has one LAN NIC and the goal is full tunnel by default).

tachiproxy_split_tunnel_sh:
  file.managed:
    - name: /usr/local/sbin/tachiproxy-split-tunnel.sh
    - source: salt://tachiproxy/files/split-tunnel.sh.jinja
    - template: jinja
    - mode: '0755'

tachiproxy_split_tunnel_service:
  file.managed:
    - name: /etc/systemd/system/tachiproxy-split-tunnel.service
    - source: salt://tachiproxy/files/split-tunnel.service.jinja
    - mode: '0644'
    - require:
      - file: tachiproxy_split_tunnel_sh

tachiproxy_split_tunnel_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: tachiproxy_split_tunnel_service

tachiproxy_split_tunnel_running:
  service.running:
    - name: tachiproxy-split-tunnel
    - enable: True
    - require:
      - file: tachiproxy_split_tunnel_service
      - cmd: tachiproxy_split_tunnel_reload
      - service: wg0_service
    - watch:
      - file: tachiproxy_split_tunnel_sh
      - file: tachiproxy_split_tunnel_service
