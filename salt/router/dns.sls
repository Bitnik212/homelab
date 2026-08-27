# systemd-resolved's stub listener holds 127.0.0.53:53/127.0.0.54:53 by
# default on Ubuntu — that conflicts with unbound's wildcard 0.0.0.0:53
# bind (Linux won't let a wildcard and a specific-address listener share a
# port), so unbound fails with "Address already in use" unless this is off.
disable_resolved_stub:
  ini.options_present:
    - name: /etc/systemd/resolved.conf
    - sections:
        Resolve:
          DNSStubListener: 'no'

resolved_restart:
  service.running:
    - name: systemd-resolved
    - watch:
      - ini: disable_resolved_stub

unbound_pkg:
  pkg.installed:
    - name: unbound

unbound_config:
  file.managed:
    - name: /etc/unbound/unbound.conf.d/homelab.conf
    - source: salt://router/files/unbound.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: unbound_pkg

unbound_service:
  service.running:
    - name: unbound
    - enable: True
    - require:
      - file: unbound_config
      - service: resolved_restart
    - watch:
      - file: unbound_config
