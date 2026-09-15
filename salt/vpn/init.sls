# vm-vpn's Caddy reverse proxy, terminating TLS for the *.bitt.app / etc
# hostnames and forwarding to the backend hosts on the LAN/VPN. Caddy itself
# (package + the caddy-stable apt repo) was installed manually before this
# state existed; this just brings the already-running config under salt so
# further edits go through git instead of hand-editing on the box.

caddy_pkg:
  pkg.installed:
    - name: caddy

caddy_config:
  file.managed:
    - name: /etc/caddy/Caddyfile
    - source: salt://vpn/files/Caddyfile
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: caddy_pkg

caddy_service:
  service.running:
    - name: caddy
    - enable: True
    - require:
      - file: caddy_config
    - watch:
      - file: caddy_config
