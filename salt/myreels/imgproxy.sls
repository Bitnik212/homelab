include:
  - docker

myreels_imgproxy_dir:
  file.directory:
    - name: /opt/myreels/imgproxy
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

myreels_imgproxy_compose:
  file.managed:
    - name: /opt/myreels/imgproxy/docker-compose.yml
    - source: salt://myreels/files/imgproxy/docker-compose.yml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: myreels_imgproxy_dir

myreels_imgproxy_up:
  cmd.run:
    - name: docker compose up -d
    - cwd: /opt/myreels/imgproxy
    - require:
      - service: docker_service
      - file: myreels_imgproxy_compose
