# Tears down router.xray, replaced by router.amneziawg. Runs LAST, after
# sing-box has already been restarted onto wg0 -- until then its config
# still points at xray's SOCKS inbound.

include:
  - router.singbox

xray_teardown_client_dead:
  service.dead:
    - name: xray-client
    - enable: False
    - require:
      - service: singbox_service

xray_teardown_files_absent:
  file.absent:
    - names:
      - /etc/systemd/system/xray-client.service
      - /etc/systemd/system/xray.service
      - /etc/systemd/system/xray.service.d
      - /etc/systemd/system/xray@.service
      - /etc/systemd/system/xray@.service.d
      - /usr/local/bin/xray
      # Holds the VLESS UUID.
      - /usr/local/etc/xray
      - /usr/local/share/xray
      - /var/log/xray
      - /var/log/xray-egress-check.log
    - require:
      - service: xray_teardown_client_dead

xray_teardown_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: xray_teardown_files_absent
