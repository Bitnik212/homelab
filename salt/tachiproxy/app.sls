include:
  - docker
  - tachiproxy.disk

tachiproxy_dir:
  file.directory:
    - name: /opt/tachiproxy
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

tachiproxy_payloads_dir:
  file.directory:
    - name: /mnt/tachiproxy/payloads
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True
    - require:
      - mount: tachiproxy_data_mounted

tachiproxy_compose:
  file.managed:
    - name: /opt/tachiproxy/docker-compose.yml
    - source: salt://tachiproxy/files/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: tachiproxy_dir

tachiproxy_env:
  file.managed:
    - name: /opt/tachiproxy/.env
    - source: salt://tachiproxy/files/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: tachiproxy_dir

# Root-owned, not world/group-writable -- filebeat runs as root (see
# docker-compose.yml) and refuses to start against a config file it
# considers too permissive.
tachiproxy_filebeat_config:
  file.managed:
    - name: /opt/tachiproxy/filebeat.yml
    - source: salt://tachiproxy/files/filebeat.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: tachiproxy_dir

# api/proxy track the floating `dev` tag, so pull explicitly on every
# apply -- `docker compose up -d` alone won't fetch a new image for a tag
# it already has locally.
tachiproxy_pull:
  cmd.run:
    - name: docker compose pull api proxy
    - cwd: /opt/tachiproxy
    - require:
      - service: docker_service
      - file: tachiproxy_compose
      - file: tachiproxy_env

tachiproxy_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/tachiproxy
    - require:
      - service: docker_service
      - file: tachiproxy_compose
      - file: tachiproxy_env
      - file: tachiproxy_filebeat_config
      - file: tachiproxy_payloads_dir
      - cmd: tachiproxy_pull

# filebeat.yml is bind-mounted (docker-compose.yml), so editing its content
# alone doesn't make `docker compose up -d` above recreate the container --
# restart it explicitly whenever the file actually changes.
tachiproxy_filebeat_restart:
  cmd.run:
    - name: docker compose restart filebeat
    - cwd: /opt/tachiproxy
    - onchanges:
      - file: tachiproxy_filebeat_config
    - require:
      - cmd: tachiproxy_up
