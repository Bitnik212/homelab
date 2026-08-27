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

consul_data_dir:
  file.directory:
    - name: /opt/consul/data
    - user: consul
    - group: consul
    - mode: '0750'
    - makedirs: True
    - require:
      - pkg: consul_pkg

consul_config:
  file.managed:
    - name: /etc/consul.d/consul.hcl
    - source: salt://consul/files/consul.hcl.jinja
    - template: jinja
    - user: consul
    - group: consul
    - mode: '0640'
    - require:
      - pkg: consul_pkg

consul_service:
  service.running:
    - name: consul
    - enable: True
    - require:
      - file: consul_data_dir
      - file: consul_config
    - watch:
      - file: consul_config
