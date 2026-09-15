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

# Turbopack's dev server (this image runs `npm run dev`, not a production
# build) only trusts localhost-ish hosts for its /_next/hmr websocket and
# rejects anything else -- even when Origin and Host match, as they do here
# -- by writing a raw, non-HTTP-framed "Unauthorized" straight to the
# socket. That breaks Caddy's reverse_proxy with a 502 (see
# salt/vpn/files/Caddyfile's psb.gremten.bitt.app block; regular page loads
# are unaffected, only hot-reload). allowedDevOrigins is Next's supported
# fix for a dev server behind a public proxy; patched in locally since
# upstream hasn't added it. Idempotent (skipped once already present) so it
# survives repeated highstates without fighting git.latest above, which
# doesn't force_reset and so leaves this local edit alone.
gremten_patch_next_config:
  cmd.run:
    - name: "sed -i '/^const nextConfig: NextConfig = {$/a\\  allowedDevOrigins: [\"psb.gremten.bitt.app\"],' next.config.ts"
    - cwd: /opt/gremten/psb
    - unless: grep -q allowedDevOrigins next.config.ts
    - require:
      - git: gremten_repo

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
      - cmd: gremten_patch_next_config
      - cmd: gremten_pull

# next.config.ts is only read at dev-server startup, not hot-reloaded --
# needed the one time gremten_patch_next_config actually changes the file
# (a container already running on an unpatched checkout).
gremten_restart_on_config_patch:
  cmd.run:
    - name: docker compose restart app
    - cwd: /opt/gremten
    - onchanges:
      - cmd: gremten_patch_next_config
    - require:
      - cmd: gremten_up
