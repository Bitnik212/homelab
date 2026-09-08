include:
  - docker
  - elk.disk

elk_dir:
  file.directory:
    - name: /opt/elk
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

# Elasticsearch's official image runs as uid 1000 (elasticsearch:root); the
# data dir must be writable by it since docker doesn't chown bind mounts
# like it does named volumes.
elk_es_data_dir:
  file.directory:
    - name: /data/elk/elasticsearch
    - user: 1000
    - group: 0
    - mode: '0750'
    - makedirs: True
    - require:
      - mount: elk_data_mounted

# Elasticsearch refuses to start below this regardless of xpack security --
# see the vm-max-map-count note in the ES docs.
elk_vm_max_map_count:
  sysctl.present:
    - name: vm.max_map_count
    - value: 262144

elk_compose:
  file.managed:
    - name: /opt/elk/docker-compose.yml
    - source: salt://elk/files/docker-compose.yml
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: elk_dir

elk_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/elk
    - require:
      - service: docker_service
      - file: elk_compose
      - file: elk_es_data_dir
      - sysctl: elk_vm_max_map_count

# ELASTIC_PASSWORD only bootstraps the "elastic" superuser -- kibana_system
# (what Kibana itself authenticates as) has no equivalent env var on the ES
# image, so its password has to be set through the security API once
# Elasticsearch is actually up. `elk_up` doesn't return until the compose
# healthcheck passes (kibana's `depends_on: condition: service_healthy`
# means compose itself waits), so ES is guaranteed reachable here.
elk_kibana_system_password:
  cmd.run:
    - name: |
        set -euo pipefail
        curl -sf -u elastic:{{ pillar['elk']['elastic_password'] }} \
          -X POST http://localhost:9200/_security/user/kibana_system/_password \
          -H 'Content-Type: application/json' \
          -d '{"password":"{{ pillar['elk']['kibana_password'] }}"}'
        # Kibana already started (and is retrying ES auth in a loop) with
        # the pillar password before it was actually set above -- restart
        # it once so it picks up the now-valid credentials immediately
        # instead of waiting out its own retry backoff.
        docker compose restart kibana
    - shell: /bin/bash
    - cwd: /opt/elk
    - unless:
      - curl -sf -u kibana_system:{{ pillar['elk']['kibana_password'] }} http://localhost:9200/_security/_authenticate
    - require:
      - cmd: elk_up
