# Deploys https://github.com/Bitnik212/splittunel-scripts, flattened into
# /opt/splittunnel (all scripts there use paths relative to their own
# directory, e.g. ./update-ruips.sh, custom_domains.txt), and wires up the
# split-tunnel systemd service. install-amneziawg.sh itself is superseded
# by router.amneziawg (kept here only as a reference copy).

splittunnel_deps:
  pkg.installed:
    - pkgs:
      - ipset
      - iptables
      - jq
      - curl

splittunnel_dir:
  file.directory:
    - name: /opt/splittunnel
    - mode: '0750'
    - makedirs: True

splittunnel_static_files:
  file.recurse:
    - name: /opt/splittunnel
    - source: salt://router/files/splittunnel
    - file_mode: '0755'
    # custom_domains.txt is user-editable data, not a script — managed
    # separately below (seed-once, never overwritten) so edits on the box
    # survive re-applies instead of getting reset to the repo's seed value.
    - exclude_pattern: custom_domains\.txt
    - require:
      - file: splittunnel_dir

# Seed-once, user-editable data files: created from the repo's version (or
# empty for asn.txt, which the repo doesn't ship) on first run, then left
# alone — state.apply must never clobber domains/ASNs you've added since.
splittunnel_asn_txt:
  file.managed:
    - name: /opt/splittunnel/asn.txt
    - replace: False
    - contents: ''
    - mode: '0644'
    - require:
      - file: splittunnel_dir

splittunnel_custom_domains_txt:
  file.managed:
    - name: /opt/splittunnel/custom_domains.txt
    - replace: False
    - source: salt://router/files/splittunnel/custom_domains.txt
    - mode: '0644'
    - require:
      - file: splittunnel_dir

split_tunnel_sh:
  file.managed:
    - name: /opt/splittunnel/split-tunnel.sh
    - source: salt://router/files/split-tunnel.sh.jinja
    - template: jinja
    - mode: '0755'
    - require:
      - file: splittunnel_dir

split_tunnel_service:
  file.managed:
    - name: /etc/systemd/system/split-tunnel.service
    - source: salt://router/files/split-tunnel.service.jinja
    - template: jinja
    - mode: '0644'
    - require:
      - file: split_tunnel_sh

splittunnel_systemd_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: split_tunnel_service

split_tunnel_service_running:
  service.running:
    - name: split-tunnel
    - enable: True
    - require:
      - pkg: splittunnel_deps
      - file: split_tunnel_service
      - file: splittunnel_asn_txt
      - file: splittunnel_custom_domains_txt
      - cmd: splittunnel_systemd_reload
      - service: wg0_service
    - watch:
      - file: split_tunnel_service
      - file: split_tunnel_sh
