unbound_pkg:
  pkg.installed:
    - name: unbound

unbound_config:
  file.managed:
    - name: /etc/unbound/unbound.conf.d/homelab.conf
    - source: salt://router/files/unbound.conf.jinja
    - template: jinja
    - user: unbound
    - group: unbound
    - mode: '0640'
    - require:
      - pkg: unbound_pkg

unbound_service:
  service.running:
    - name: unbound
    - enable: True
    - require:
      - file: unbound_config
    - watch:
      - file: unbound_config
