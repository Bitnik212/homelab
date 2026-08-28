include:
  - docker

myreels_reels_api_dir:
  file.directory:
    - name: /opt/myreels/reels-api
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

myreels_reels_api_compose:
  file.managed:
    - name: /opt/myreels/reels-api/docker-compose.yml
    - source: salt://myreels/files/reels-api/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: myreels_reels_api_dir

myreels_reels_api_env:
  file.managed:
    - name: /opt/myreels/reels-api/.env
    - source: salt://myreels/files/reels-api/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: myreels_reels_api_dir

myreels_reels_api_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/myreels/reels-api
    - require:
      - service: docker_service
      - file: myreels_reels_api_compose
      - file: myreels_reels_api_env
