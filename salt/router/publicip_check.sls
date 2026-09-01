# Watchdog for router.splittunnel: every 5 min, confirm router-1's public
# egress IP still matches the AmneziaWG endpoint (i.e. wg0 is actually
# carrying default traffic) and restart split-tunnel.service if it's
# drifted back to plain WAN egress.

cron_pkg:
  pkg.installed:
    - name: cron
    # Without this, cron.present below fails on a fresh box: Salt's cron
    # execution module __virtual__-checks for the crontab binary once at
    # module-load time (start of run), before this state has installed
    # it -- reload_modules forces that check to happen again afterward.
    - reload_modules: True

check_public_ip_sh:
  file.managed:
    - name: /opt/splittunnel/check-public-ip.sh
    - source: salt://router/files/check-public-ip.sh.jinja
    - template: jinja
    - mode: '0755'
    - require:
      - file: splittunnel_dir

check_public_ip_cron:
  cron.present:
    - name: /opt/splittunnel/check-public-ip.sh >> /var/log/splittunnel-ipcheck.log 2>&1
    - identifier: splittunnel_public_ip_check
    - user: root
    - minute: '*/5'
    - require:
      - pkg: cron_pkg
      - file: check_public_ip_sh
      - service: split_tunnel_service_running
