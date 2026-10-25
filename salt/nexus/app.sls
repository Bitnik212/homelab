include:
  - docker
  - nexus.disk

nexus_dir:
  file.directory:
    - name: /opt/nexus
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

nexus_compose:
  file.managed:
    - name: /opt/nexus/docker-compose.yml
    - source: salt://nexus/files/docker-compose.yml
    - mode: '0644'
    - require:
      - file: nexus_dir

nexus_env:
  file.managed:
    - name: /opt/nexus/.env
    - source: salt://nexus/files/env.jinja
    - template: jinja
    - mode: '0600'
    - require:
      - file: nexus_dir

nexus_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/nexus
    - require:
      - service: docker_service
      - file: nexus_compose
      - file: nexus_env
      - cmd: nexus_blobs_dir

nexus_bootstrap_deps:
  pkg.installed:
    - pkgs:
      - curl
      - jq

nexus_bootstrap_script:
  file.managed:
    - name: /opt/nexus/bootstrap.sh
    - source: salt://nexus/files/bootstrap.sh.jinja
    - template: jinja
    - mode: '0700'
    - require:
      - file: nexus_dir

# Idempotent (see the script), so safe to run every apply -- also how a
# repo deleted by hand in the UI comes back.
nexus_bootstrap:
  cmd.run:
    - name: /opt/nexus/bootstrap.sh
    - require:
      - cmd: nexus_up
      - pkg: nexus_bootstrap_deps
      - file: nexus_bootstrap_script
