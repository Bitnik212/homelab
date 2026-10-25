# Xray VLESS/REALITY client for router-1 -- replaces router.amneziawg (the
# AWG tunnel stopped working reliably). Only exposes a local SOCKS inbound
# on 127.0.0.1:1080; router.singbox's tun is what actually steers traffic
# into it. Salt version of install-xray-singbox.sh's xray half; the config
# itself (client.json) is generated from pillar's vless_url by
# router.proxy_config.

include:
  - router.awg_teardown
  - router.proxy_config

xray_deps:
  pkg.installed:
    - pkgs:
      - curl
      - ca-certificates
      - iproute2

# Upstream's installer drops the binary at /usr/local/bin/xray (plus geo
# data under /usr/local/share/xray). The trailing test catches the case
# where curl fails and `bash -c ""` happily exits 0 having installed
# nothing.
xray_install:
  cmd.run:
    - name: >-
        bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &&
        test -x /usr/local/bin/xray
    - unless: test -x /usr/local/bin/xray
    - require:
      - pkg: xray_deps
      - cmd: awg_teardown_routing

# install-release.sh also ships its own xray.service (User=nobody, reading
# /usr/local/etc/xray/config.json) -- unused here, xray-client.service below
# runs client.json instead. Masked, not just disabled: config.json is
# empty, so a manual `systemctl start xray` only produces a confusing exit-23
# "failed to read config" failure next to the working xray-client.
xray_stock_service_disabled:
  service.masked:
    - name: xray
    - require:
      - cmd: xray_install

xray_config_dir:
  file.directory:
    - name: /usr/local/etc/xray
    - mode: '0755'
    - makedirs: True

xray_client_unit:
  file.managed:
    - name: /etc/systemd/system/xray-client.service
    - source: salt://router/files/xray-client.service
    - mode: '0644'
    - require:
      - cmd: xray_install

xray_client_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: xray_client_unit

xray_client_service:
  service.running:
    - name: xray-client
    - enable: True
    - require:
      - file: xray_client_unit
      - cmd: xray_client_reload
      - file: xray_client_config
      - service: xray_stock_service_disabled
    - watch:
      - file: xray_client_unit
      - file: xray_client_config
