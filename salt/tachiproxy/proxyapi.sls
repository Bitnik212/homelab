# Proxy API (registry.gitlab.com/bitnik212/proxyapi:develop) -- panel + API
# for managing the proxy list, on vm-tachiproxy next to the versioned proxy
# itself. Separate compose project in /opt/proxyapi
# (files/proxyapi-compose.yml) on port 8200, public as proxy.bitt.app via
# vm-vpn's Caddy (salt/vpn/files/Caddyfile). Its health checks go out
# through each proxy from this VM, so Proxyline IPs ride the wg0 routes
# tachiproxy.proxyroute installs, same as tachiproxy's own upstream traffic.
include:
  - docker

proxyapi_dir:
  file.directory:
    - name: /opt/proxyapi
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

proxyapi_compose:
  file.managed:
    - name: /opt/proxyapi/docker-compose.yml
    - source: salt://tachiproxy/files/proxyapi-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: proxyapi_dir

proxyapi_env:
  file.managed:
    - name: /opt/proxyapi/.env
    - source: salt://tachiproxy/files/proxyapi-env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: proxyapi_dir

# develop is a floating tag -- `docker compose up -d` alone won't fetch a
# new image for a tag it already has locally.
proxyapi_pull:
  cmd.run:
    - name: docker compose pull
    - cwd: /opt/proxyapi
    - require:
      - service: docker_service
      - file: proxyapi_compose

proxyapi_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/proxyapi
    - require:
      - service: docker_service
      - file: proxyapi_compose
      - file: proxyapi_env
      - cmd: proxyapi_pull

# env_file changes don't make `up -d` recreate the containers on their own.
proxyapi_recreate_on_env_change:
  cmd.run:
    - name: docker compose up -d --force-recreate
    - cwd: /opt/proxyapi
    - onchanges:
      - file: proxyapi_env
    - require:
      - cmd: proxyapi_up
