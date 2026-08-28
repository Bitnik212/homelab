include:
  - docker

myreels_reels_bot_dir:
  file.directory:
    - name: /opt/myreels/reels-bot
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

myreels_reels_bot_compose:
  file.managed:
    - name: /opt/myreels/reels-bot/docker-compose.yml
    - source: salt://myreels/files/reels-bot/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: myreels_reels_bot_dir

myreels_reels_bot_env:
  file.managed:
    - name: /opt/myreels/reels-bot/.env
    - source: salt://myreels/files/reels-bot/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: myreels_reels_bot_dir

myreels_reels_bot_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/myreels/reels-bot
    - require:
      - service: docker_service
      - file: myreels_reels_bot_compose
      - file: myreels_reels_bot_env
