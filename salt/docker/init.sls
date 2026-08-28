docker_repo_deps:
  pkg.installed:
    - names:
      - ca-certificates
      - curl
      - gnupg

docker_keyring_dir:
  file.directory:
    - name: /etc/apt/keyrings
    - mode: '0755'

docker_gpg_key:
  cmd.run:
    - name: >-
        set -o pipefail;
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    - shell: /bin/bash
    - unless: gpg --show-keys /etc/apt/keyrings/docker.gpg
    - require:
      - file: docker_keyring_dir
      - pkg: docker_repo_deps

docker_apt_repo:
  pkgrepo.managed:
    - name: deb [arch={{ grains['osarch'] }} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu {{ grains['oscodename'] }} stable
    - file: /etc/apt/sources.list.d/docker.list
    - require:
      - cmd: docker_gpg_key

docker_pkgs:
  pkg.installed:
    - names:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-compose-plugin
    - refresh: True
    - require:
      - pkgrepo: docker_apt_repo

docker_service:
  service.running:
    - name: docker
    - enable: True
    - require:
      - pkg: docker_pkgs
