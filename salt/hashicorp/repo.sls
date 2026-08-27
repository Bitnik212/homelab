hashicorp_repo_deps:
  pkg.installed:
    - names:
      - wget
      - gnupg

hashicorp_apt_key:
  cmd.run:
    - name: wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    - creates: /usr/share/keyrings/hashicorp-archive-keyring.gpg
    - require:
      - pkg: hashicorp_repo_deps

hashicorp_apt_repo:
  pkgrepo.managed:
    - name: deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com {{ grains['oscodename'] }} main
    - file: /etc/apt/sources.list.d/hashicorp.list
    - require:
      - cmd: hashicorp_apt_key
