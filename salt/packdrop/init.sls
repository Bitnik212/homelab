# Packdrop (https://gitlab.com/Bitnik212/packdrop), co-located on
# vm-curseforge next to the CurseForge proxy it talks to. Unlike
# curseforge-api's dev image, :latest is the repo's prod target (nginx +
# uWSGI, source baked in), so there's no checkout to bind-mount. It reaches
# the proxy by its public hostname (files/env.jinja), not over localhost --
# curseforge's DJANGO_ALLOWED_HOSTS doesn't include any internal name -- but
# pinned to 10.20.10.4 via extra_hosts (files/docker-compose.yml).
#
# curseforge.network is pulled in for the apt mirror fix docker_pkgs needs.
include:
  - docker
  - curseforge.network
  - packdrop.disk

packdrop_dir:
  file.directory:
    - name: /opt/packdrop
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

packdrop_compose:
  file.managed:
    - name: /opt/packdrop/docker-compose.yml
    - source: salt://packdrop/files/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: packdrop_dir

packdrop_env:
  file.managed:
    - name: /opt/packdrop/.env.prod
    - source: salt://packdrop/files/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: packdrop_dir

# latest is a floating tag -- `docker compose up -d` alone won't fetch a
# new image for a tag it already has locally.
packdrop_pull:
  cmd.run:
    - name: docker compose pull
    - cwd: /opt/packdrop
    - require:
      - service: docker_service
      - file: packdrop_compose

packdrop_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/packdrop
    - require:
      - service: docker_service
      - file: packdrop_compose
      - file: packdrop_env
      - file: packdrop_storage_owner
      - cmd: packdrop_pull

# env_file changes don't make `up -d` recreate the containers on their own.
# (compose.yml changes, like extra_hosts, do.)
packdrop_recreate_on_env_change:
  cmd.run:
    - name: docker compose up -d --force-recreate
    - cwd: /opt/packdrop
    - onchanges:
      - file: packdrop_env
    - require:
      - cmd: packdrop_up
