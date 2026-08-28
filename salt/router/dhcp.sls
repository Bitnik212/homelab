# DHCP server for the hashibr network (10.30.30.0/24 by default) — serves
# addresses to vault-*/consul-* once their NICs move onto that bridge.

isc_dhcp_server_pkg:
  pkg.installed:
    - name: isc-dhcp-server

dhcpd_config:
  file.managed:
    - name: /etc/dhcp/dhcpd.conf
    - source: salt://router/files/dhcpd.conf.jinja
    - template: jinja
    - mode: '0644'
    - require:
      - pkg: isc_dhcp_server_pkg

isc_dhcp_server_defaults:
  file.managed:
    - name: /etc/default/isc-dhcp-server
    - source: salt://router/files/isc-dhcp-server.jinja
    - template: jinja
    - mode: '0644'
    - require:
      - pkg: isc_dhcp_server_pkg

isc_dhcp_server_service:
  service.running:
    - name: isc-dhcp-server
    - enable: True
    - require:
      - file: dhcpd_config
      - file: isc_dhcp_server_defaults
    - watch:
      - file: dhcpd_config
      - file: isc_dhcp_server_defaults
