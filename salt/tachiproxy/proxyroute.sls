# Replaces tachiproxy.splittunnel (full tunnel + RU-ipset split, same
# bundle as router-1's -- didn't work out here) with a plain per-IP static
# route for just the active upstream proxy IPs, same shape as
# salt/elk/hashibr_route.sls. wg0 stays Table = off (salt/tachiproxy/
# amneziawg.sls); nothing here manages a default route at all.

# --- Tear down the earlier splittunnel bundle this replaces ---

tachiproxy_splittunnel_service_disabled:
  service.dead:
    - name: split-tunnel
    - enable: False

# split-tunnel.sh's own ip rules / ipset / iptables mangle chains / NAT
# rule / resolved override have no uninstall path of their own (the unit
# has no ExecStop) -- has to be undone by hand, once, before the routes it
# owned (esp. pref 200's default-via-wg0) get replaced by anything else.
tachiproxy_splittunnel_routing_teardown:
  cmd.run:
    - name: |
        set -e
        for pref in 40 41 45 50 100 200; do
          ip rule del pref "$pref" 2>/dev/null || true
        done
        ip route flush table vpn 2>/dev/null || true
        iptables -t mangle -D OUTPUT -j SPLIT_OUT 2>/dev/null || true
        iptables -t mangle -D PREROUTING -j SPLIT_PRE 2>/dev/null || true
        iptables -t mangle -F SPLIT_OUT 2>/dev/null || true
        iptables -t mangle -X SPLIT_OUT 2>/dev/null || true
        iptables -t mangle -F SPLIT_PRE 2>/dev/null || true
        iptables -t mangle -X SPLIT_PRE 2>/dev/null || true
        iptables -t mangle -D PREROUTING -s 172.16.0.0/12 -m set --match-set ru dst -j MARK --set-mark 0x1 2>/dev/null || true
        iptables -t mangle -D PREROUTING -s 172.16.0.0/12 -m set --match-set ru dst -j CONNMARK --save-mark 2>/dev/null || true
        iptables -t mangle -D PREROUTING -i eth0 -j CONNMARK --set-mark 0x1 2>/dev/null || true
        iptables -t mangle -D OUTPUT -m connmark --mark 0x1 -j MARK --set-mark 0x1 2>/dev/null || true
        iptables -t mangle -D PREROUTING -m conntrack --ctstate RELATED,ESTABLISHED -j CONNMARK --restore-mark 2>/dev/null || true
        iptables -t nat -D POSTROUTING -m mark --mark 0x1 -o eth0 -j MASQUERADE 2>/dev/null || true
        ipset destroy ru 2>/dev/null || true
        resolvectl revert wg0 2>/dev/null || true
        ip route flush cache
    - require:
      - service: tachiproxy_splittunnel_service_disabled

tachiproxy_splittunnel_unit_absent:
  file.absent:
    - name: /etc/systemd/system/split-tunnel.service
    - require:
      - cmd: tachiproxy_splittunnel_routing_teardown

tachiproxy_splittunnel_dir_absent:
  file.absent:
    - name: /opt/splittunnel
    - require:
      - cmd: tachiproxy_splittunnel_routing_teardown

tachiproxy_splittunnel_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: tachiproxy_splittunnel_unit_absent

# --- New: static routes for just the active proxy IPs ---

tachiproxy_proxy_route_deps:
  pkg.installed:
    - pkgs:
      - jq
      - curl

tachiproxy_proxy_route_script:
  file.managed:
    - name: /usr/local/sbin/tachiproxy-proxy-route.sh
    - source: salt://tachiproxy/files/proxy-route.sh.jinja
    - template: jinja
    - mode: '0700'
    - require:
      - pkg: tachiproxy_proxy_route_deps

# From when this was a directly-enabled boot-time oneshot, before the
# timer below replaced it -- dropping [Install] from the unit file doesn't
# remove an existing enablement symlink on its own, so without this it'd
# still fire once at boot in addition to the timer.
tachiproxy_proxy_route_old_enablement_disabled:
  cmd.run:
    - name: systemctl disable tachiproxy-proxy-route.service
    - onlyif: systemctl is-enabled --quiet tachiproxy-proxy-route.service

tachiproxy_proxy_route_service:
  file.managed:
    - name: /etc/systemd/system/tachiproxy-proxy-route.service
    - source: salt://tachiproxy/files/proxy-route.service.jinja
    - mode: '0644'
    - require:
      - file: tachiproxy_proxy_route_script
      - cmd: tachiproxy_proxy_route_old_enablement_disabled

# ProxyLine rotates which IPs are active over the VM's uptime, so this
# can't just be a boot-time oneshot (salt/elk/hashibr_route.sls's
# equivalent gets away with that since DNS-backed CDN IPs are far more
# stable) -- re-run on a timer instead.
tachiproxy_proxy_route_timer_unit:
  file.managed:
    - name: /etc/systemd/system/tachiproxy-proxy-route.timer
    - source: salt://tachiproxy/files/proxy-route.timer
    - mode: '0644'
    - require:
      - file: tachiproxy_proxy_route_service

tachiproxy_proxy_route_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: tachiproxy_proxy_route_service
      - file: tachiproxy_proxy_route_timer_unit

tachiproxy_proxy_route_timer_running:
  service.running:
    - name: tachiproxy-proxy-route.timer
    - enable: True
    - require:
      - file: tachiproxy_proxy_route_timer_unit
      - cmd: tachiproxy_proxy_route_reload
      - service: wg0_service
      - file: tachiproxy_splittunnel_dir_absent
    - watch:
      - file: tachiproxy_proxy_route_timer_unit

# The timer's OnBootSec=1min means a fresh apply would otherwise wait up
# to a minute for the first run -- trigger it immediately instead so
# routes exist right away. `restart`, not `start`: a oneshot unit that's
# already active(exited) treats `start` as a no-op and won't actually
# re-run the script.
tachiproxy_proxy_route_run_now:
  cmd.run:
    - name: systemctl restart tachiproxy-proxy-route.service
    - require:
      - service: tachiproxy_proxy_route_timer_running
