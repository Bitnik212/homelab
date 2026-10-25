# nginx on :80 in front of Nexus (127.0.0.1:8081) with its own proxy_cache
# on the NAS (/mnt/nexus/nginx-cache, nexus.disk) -- repeat downloads of the
# same artifact are served straight from nginx without touching Nexus's JVM
# at all. See files/nginx-nexus.conf.jinja for what's cached for how long.

nexus_nginx_pkg:
  pkg.installed:
    - name: nginx

nexus_nginx_config:
  file.managed:
    - name: /etc/nginx/sites-available/nexus.conf
    - source: salt://nexus/files/nginx-nexus.conf.jinja
    - template: jinja
    - mode: '0644'
    - require:
      - pkg: nexus_nginx_pkg

nexus_nginx_enabled:
  file.symlink:
    - name: /etc/nginx/sites-enabled/nexus.conf
    - target: /etc/nginx/sites-available/nexus.conf
    - require:
      - file: nexus_nginx_config

nexus_nginx_default_site_disabled:
  file.absent:
    - name: /etc/nginx/sites-enabled/default
    - require:
      - pkg: nexus_nginx_pkg

nexus_nginx_service:
  service.running:
    - name: nginx
    - enable: True
    - require:
      - file: nexus_nginx_enabled
      - file: nexus_nginx_default_site_disabled
      - file: nexus_nginx_cache_dir
    - watch:
      - file: nexus_nginx_config
