# Dev deployment of packdrop as dev.packdrop.bitt.app, next to prod
# (init.sls) on vm-curseforge. Runs the :develop image with the same env
# (files/env.jinja, same pillar) apart from the domain. Its media stays on
# local disk rather than the NAS so dev builds never mix with prod's.
#
# curseforge.network is pulled in for the apt mirror fix docker_pkgs needs;
# it only compiles alongside curseforge.disk (its require_in names
# curseforge_nfs_common), so that comes along too.
include:
  - docker
  - curseforge.network
  - curseforge.disk

packdrop_dev_dir:
  file.directory:
    - name: /opt/packdrop-dev
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

# The image runs as uid 1000 "app".
packdrop_dev_media:
  file.directory:
    - name: /opt/packdrop-dev/media
    - user: 1000
    - group: 1000
    - mode: '0755'
    - require:
      - file: packdrop_dev_dir

packdrop_dev_compose:
  file.managed:
    - name: /opt/packdrop-dev/docker-compose.yml
    - source: salt://packdrop/files/docker-compose.dev.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: packdrop_dev_dir

packdrop_dev_env:
  file.managed:
    - name: /opt/packdrop-dev/.env.prod
    - source: salt://packdrop/files/env.jinja
    - template: jinja
    - context:
        domain: dev.packdrop.bitt.app
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: packdrop_dev_dir

# develop is a floating tag, same as :latest in init.sls.
packdrop_dev_pull:
  cmd.run:
    - name: docker compose pull
    - cwd: /opt/packdrop-dev
    - require:
      - service: docker_service
      - file: packdrop_dev_compose

packdrop_dev_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/packdrop-dev
    - require:
      - service: docker_service
      - file: packdrop_dev_compose
      - file: packdrop_dev_env
      - file: packdrop_dev_media
      - cmd: packdrop_dev_pull

packdrop_dev_recreate_on_env_change:
  cmd.run:
    - name: docker compose up -d --force-recreate
    - cwd: /opt/packdrop-dev
    - onchanges:
      - file: packdrop_dev_env
    - require:
      - cmd: packdrop_dev_up
