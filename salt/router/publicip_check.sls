# Watchdog for router.singbox: every 5 min, confirm router-1's public
# egress IP still matches the xray server (i.e. tun0 -> xray is actually
# carrying default traffic) and restart xray-client + sing-box if it's
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
    - name: /usr/local/sbin/check-public-ip.sh
    - source: salt://router/files/check-public-ip.sh.jinja
    - template: jinja
    - mode: '0755'

# Same identifier as the old split-tunnel version, so this replaces that
# crontab line in place rather than adding a second one.
check_public_ip_cron:
  cron.present:
    - name: /usr/local/sbin/check-public-ip.sh >> /var/log/xray-egress-check.log 2>&1
    - identifier: splittunnel_public_ip_check
    - user: root
    - minute: '*/5'
    - require:
      - pkg: cron_pkg
      - file: check_public_ip_sh
      - service: singbox_service
