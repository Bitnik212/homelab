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
    - user: root
    - group: root
    - mode: '0644'
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
