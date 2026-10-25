include:
  - docker
  - grafana.disk

grafana_dir:
  file.directory:
    - name: /opt/grafana
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

# The prom/prometheus image runs as nobody (65534) and grafana/grafana as
# 472; docker doesn't chown bind mounts, so each data dir has to be
# writable by its container's uid up front.
grafana_prometheus_data_dir:
  file.directory:
    - name: /data/grafana/prometheus
    - user: 65534
    - group: 65534
    - mode: '0750'
    - require:
      - mount: grafana_data_mounted

grafana_grafana_data_dir:
  file.directory:
    - name: /data/grafana/grafana
    - user: 472
    - group: 0
    - mode: '0750'
    - require:
      - mount: grafana_data_mounted

grafana_compose:
  file.managed:
    - name: /opt/grafana/docker-compose.yml
    - source: salt://grafana/files/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: grafana_dir

grafana_env:
  file.managed:
    - name: /opt/grafana/.env
    - source: salt://grafana/files/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: grafana_dir

grafana_prometheus_config:
  file.managed:
    - name: /opt/grafana/prometheus.yml
    - source: salt://grafana/files/prometheus.yml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: grafana_dir

# Datasource + dashboard provider configs and the dashboard JSON itself;
# grafana reads them read-only from the bind mount on startup.
grafana_provisioning:
  file.recurse:
    - name: /opt/grafana/provisioning
    - source: salt://grafana/files/provisioning
    - user: root
    - group: root
    - dir_mode: '0755'
    - file_mode: '0644'
    - clean: True
    - require:
      - file: grafana_dir

grafana_dashboards:
  file.recurse:
    - name: /opt/grafana/dashboards
    - source: salt://grafana/files/dashboards
    - user: root
    - group: root
    - dir_mode: '0755'
    - file_mode: '0644'
    - clean: True
    - require:
      - file: grafana_dir

grafana_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/grafana
    - require:
      - service: docker_service
      - file: grafana_compose
      - file: grafana_env
      - file: grafana_prometheus_config
      - file: grafana_provisioning
      - file: grafana_dashboards
      - file: grafana_prometheus_data_dir
      - file: grafana_grafana_data_dir

# Config files are bind-mounted, so editing them alone doesn't make
# `docker compose up -d` above recreate the containers -- restart whichever
# one reads a file that actually changed.
grafana_prometheus_restart:
  cmd.run:
    - name: docker compose restart prometheus
    - cwd: /opt/grafana
    - onchanges:
      - file: grafana_prometheus_config
    - require:
      - cmd: grafana_up

grafana_grafana_restart:
  cmd.run:
    - name: docker compose restart grafana
    - cwd: /opt/grafana
    - onchanges:
      - file: grafana_provisioning
    - require:
      - cmd: grafana_up
