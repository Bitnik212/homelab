# Local nginx on vm-myreels-bot itself, routing by Host header to the
# containers' published ports. The external SSL-terminating proxy talks
# plain HTTP to this box on port 80; router-1's own proxy_pass (see
# salt/router/nginx.sls) hits the container ports directly and doesn't
# depend on this.

nginx_pkg:
  pkg.installed:
    - name: nginx

nginx_config:
  file.managed:
    - name: /etc/nginx/sites-available/myreels.conf
    - source: salt://myreels/files/nginx.conf
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: nginx_pkg

nginx_enabled:
  file.symlink:
    - name: /etc/nginx/sites-enabled/myreels.conf
    - target: /etc/nginx/sites-available/myreels.conf
    - require:
      - file: nginx_config

nginx_default_site_disabled:
  file.absent:
    - name: /etc/nginx/sites-enabled/default
    - require:
      - pkg: nginx_pkg

nginx_service:
  service.running:
    - name: nginx
    - enable: True
    - require:
      - file: nginx_enabled
      - file: nginx_default_site_disabled
    - watch:
      - file: nginx_config
