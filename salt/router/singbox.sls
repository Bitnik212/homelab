# sing-box tun (tun0) on router-1 -- steers router-1's own traffic and
# everything it forwards for hashibr into router.xray's local SOCKS proxy,
# replacing router.splittunnel's wg0 + RU-ipset policy routing (torn down
# by router.awg_teardown). Salt version of install-xray-singbox.sh's
# sing-box half plus setup-xray-singbox.sh; config.json itself comes from
# router.proxy_config.
#
# hashibr's NAT keeps working unchanged: router.nat masquerades
# 10.30.30.0/24 with no -o restriction, so forwarded traffic routed into
# tun0 gets SNAT'd onto it the same way it used to onto wg0.

{%- set sb = pillar.get('router', {}).get('singbox', {}) %}
{%- set rollback = sb.get('rollback_after_seconds', 0) | int %}

include:
  - router.xray
  - router.awg_teardown
  - router.proxy_config

# deb-install.sh pulls the latest release .deb from GitHub and dpkg -i's
# it (no apt repo, so this never upgrades on its own) -- it downloads into
# cwd, hence /tmp.
singbox_install:
  cmd.run:
    - name: curl -fsSL https://sing-box.app/deb-install.sh | bash && test -x /usr/bin/sing-box
    - cwd: /tmp
    - unless: test -x /usr/bin/sing-box
    - require:
      - pkg: xray_deps
      - cmd: awg_teardown_routing

singbox_config_dir:
  file.directory:
    - name: /etc/sing-box
    - mode: '0755'
    - makedirs: True

# sing-box's auto_route sends everything not in route_exclude_address into
# tun0 -- including router-1's replies on connections that came IN from
# outside the excluded ranges (e.g. nginx on :80 answering a non-LAN
# client), which would otherwise leave via the proxy and never reach the
# client. Pinning those source ports to the main table keeps inbound
# services answering from the real WAN IP.
singbox_bypass_incoming_script:
  file.managed:
    - name: /usr/local/sbin/sing-box-bypass-incoming.sh
    - source: salt://router/files/sing-box-bypass-incoming.sh.jinja
    - template: jinja
    - mode: '0755'

singbox_dropin:
  file.managed:
    - name: /etc/systemd/system/sing-box.service.d/override.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        [Service]
        ExecStartPost=/usr/local/sbin/sing-box-bypass-incoming.sh
    - require:
      - file: singbox_bypass_incoming_script

singbox_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: singbox_dropin

{%- if rollback > 0 %}

# Same safety net as setup-xray-singbox.sh's step 6: if this restart cuts
# off access, sing-box gets stopped again on its own after N seconds
# (routing falls straight back to plain WAN). Only armed when the restart
# below is actually going to happen. Cancel once things look fine with
#   systemctl stop rollback-singbox.timer
# and set router:singbox:rollback_after_seconds back to 0 -- left armed,
# every config change re-arms it.
singbox_rollback_arm:
  cmd.run:
    - name: >-
        systemctl stop rollback-singbox.timer rollback-singbox.service 2>/dev/null;
        systemctl reset-failed rollback-singbox.service 2>/dev/null;
        systemd-run --on-active={{ rollback }} --unit=rollback-singbox.service systemctl stop sing-box
    - onchanges:
      - file: singbox_config
      - file: singbox_dropin
      - file: singbox_bypass_incoming_script
    # Arm as late as possible, i.e. right before singbox_service --
    # otherwise the xray install + AWG teardown in between can eat the
    # whole window and the timer fires before sing-box has even started.
    - require:
      - cmd: singbox_install
      - cmd: singbox_reload
      - service: xray_client_service
      - cmd: awg_teardown_routing
    - require_in:
      - service: singbox_service
{%- endif %}

singbox_service:
  service.running:
    - name: sing-box
    - enable: True
    - require:
      - cmd: singbox_install
      - cmd: singbox_reload
      - file: singbox_config
      - service: xray_client_service
      - cmd: awg_teardown_routing
    - watch:
      - file: singbox_config
      - file: singbox_dropin
      - file: singbox_bypass_incoming_script
