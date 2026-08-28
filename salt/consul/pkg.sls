include:
  - hashicorp.repo

consul_version_pin:
  file.managed:
    - name: /etc/apt/preferences.d/hashicorp-consul
    - contents: |
        Package: consul
        Pin: version {{ pillar.get('consul_version', '1.22.7-1') }}
        Pin-Priority: 1001
    - require:
      - pkgrepo: hashicorp_apt_repo

consul_pkg:
  pkg.latest:
    - name: consul
    - refresh: True
    - require:
      - pkgrepo: hashicorp_apt_repo
      - file: consul_version_pin
