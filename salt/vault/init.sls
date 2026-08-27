include:
  - hashicorp.repo

vault_version_pin:
  file.managed:
    - name: /etc/apt/preferences.d/hashicorp-vault
    - contents: |
        Package: vault
        Pin: version {{ pillar.get('vault_version', '1.21.4-1') }}
        Pin-Priority: 1001
    - require:
      - pkgrepo: hashicorp_apt_repo

vault_pkg:
  pkg.latest:
    - name: vault
    - refresh: True
    - require:
      - pkgrepo: hashicorp_apt_repo
      - file: vault_version_pin

vault_data_dir:
  file.directory:
    - name: /opt/vault/data
    - user: vault
    - group: vault
    - mode: '0750'
    - makedirs: True
    - require:
      - pkg: vault_pkg

vault_config:
  file.managed:
    - name: /etc/vault.d/vault.hcl
    - source: salt://vault/files/vault.hcl.jinja
    - template: jinja
    - user: vault
    - group: vault
    - mode: '0640'
    - require:
      - pkg: vault_pkg

vault_service:
  service.running:
    - name: vault
    - enable: True
    - require:
      - file: vault_data_dir
      - file: vault_config
    - watch:
      - file: vault_config
