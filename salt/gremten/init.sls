include:
  - docker

gremten_dir:
  file.directory:
    - name: /opt/gremten
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

gremten_git_pkg:
  pkg.installed:
    - name: git

# ghcr.io/gremten/psb:main (built from the repo's Dockerfile.dev) is a bare
# node:22-bookworm-slim + build tools -- it has no app source baked in and
# expects the repo bind-mounted at /app, same as the repo's own
# docker-compose.yml does for local dev. So the actual source lives here on
# the host and gets bind-mounted in (see files/docker-compose.yml); without
# it the container has no package.json and crash-loops on `npm run dev`.
gremten_repo:
  git.latest:
    - name: https://github.com/gremten/PSB.git
    - rev: main
    - target: /opt/gremten/psb
    - require:
      - pkg: gremten_git_pkg
      - file: gremten_dir

gremten_compose:
  file.managed:
    - name: /opt/gremten/docker-compose.yml
    - source: salt://gremten/files/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: gremten_dir

gremten_env:
  file.managed:
    - name: /opt/gremten/.env
    - source: salt://gremten/files/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: gremten_dir

# main tracks a floating tag -- `docker compose up -d` alone won't fetch a
# new image for a tag it already has locally, same reasoning as
# tachiproxy_mangachan_pull (salt/tachiproxy_mangachan/app.sls).
gremten_pull:
  cmd.run:
    - name: docker compose pull
    - cwd: /opt/gremten
    - require:
      - service: docker_service
      - file: gremten_compose

gremten_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/gremten
    - require:
      - service: docker_service
      - file: gremten_compose
      - file: gremten_env
      - git: gremten_repo
      - cmd: gremten_pull
