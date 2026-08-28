# Plain-HTTP reverse proxy into hashibr-only VMs (e.g. vm-myreels-bot) --
# no TLS termination here yet, see pillar/router.sls "proxy.vhosts" for the
# domain -> upstream mapping.

nginx_pkg:
  pkg.installed:
    - name: nginx

nginx_proxy_config:
  file.managed:
    - name: /etc/nginx/sites-available/homelab-proxy.conf
    - source: salt://router/files/nginx-proxy.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: nginx_pkg

nginx_proxy_enabled:
  file.symlink:
    - name: /etc/nginx/sites-enabled/homelab-proxy.conf
    - target: /etc/nginx/sites-available/homelab-proxy.conf
    - require:
      - file: nginx_proxy_config

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
      - file: nginx_proxy_enabled
      - file: nginx_default_site_disabled
    - watch:
      - file: nginx_proxy_config
