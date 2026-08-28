# Consul client agent -- for nodes that need to reach a Consul cluster
# (e.g. Vault's service_registration "consul" stanza) without being a
# Consul server themselves. See consul/init.sls for the server role.

include:
  - consul.pkg

consul_client_data_dir:
  file.directory:
    - name: /opt/consul/data
    - user: consul
    - group: consul
    - mode: '0750'
    - makedirs: True
    - require:
      - pkg: consul_pkg

consul_client_config:
  file.managed:
    - name: /etc/consul.d/consul.hcl
    - source: salt://consul/files/consul-client.hcl.jinja
    - template: jinja
    - user: consul
    - group: consul
    - mode: '0640'
    - require:
      - pkg: consul_pkg

consul_client_service:
  service.running:
    - name: consul
    - enable: True
    - require:
      - file: consul_client_data_dir
      - file: consul_client_config
    - watch:
      - file: consul_client_config
