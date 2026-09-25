include:
  - docker
  - curseforge.disk

curseforge_dir:
  file.directory:
    - name: /opt/curseforge
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

curseforge_git_pkg:
  pkg.installed:
    - name: git

# registry.gitlab.com/bitnik212/curseforge-api:develop is the repo's dev
# image (docker/dev/Dockerfile): just python + requirements, no app source
# baked in -- it expects the checkout bind-mounted at /app, same as the
# repo's own docker/dev/compose.yml and the same situation as
# salt/gremten/init.sls. Tracks develop to match the image tag.
curseforge_repo:
  git.latest:
    - name: https://gitlab.com/Bitnik212/curseforge-api.git
    - rev: develop
    - branch: develop
    - target: /opt/curseforge/src
    - force_reset: True
    - require:
      - pkg: curseforge_git_pkg
      - file: curseforge_dir

curseforge_compose:
  file.managed:
    - name: /opt/curseforge/docker-compose.yml
    - source: salt://curseforge/files/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: curseforge_dir

curseforge_env:
  file.managed:
    - name: /opt/curseforge/.env
    - source: salt://curseforge/files/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: curseforge_dir

# develop is a floating tag -- `docker compose up -d` alone won't fetch a
# new image for a tag it already has locally.
curseforge_pull:
  cmd.run:
    - name: docker compose pull
    - cwd: /opt/curseforge
    - require:
      - service: docker_service
      - file: curseforge_compose

curseforge_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/curseforge
    - require:
      - service: docker_service
      - file: curseforge_compose
      - file: curseforge_env
      - mount: curseforge_storage_mounted
      - git: curseforge_repo
      - cmd: curseforge_pull

# runserver's autoreloader picks up source changes on its own, but
# migrations only run from the entrypoint at container start.
curseforge_restart_on_repo_change:
  cmd.run:
    - name: docker compose restart web
    - cwd: /opt/curseforge
    - onchanges:
      - git: curseforge_repo
    - require:
      - cmd: curseforge_up
