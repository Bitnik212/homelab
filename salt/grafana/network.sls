# net1 (eth1) is on hashibr purely so Prometheus can scrape hashibr-only
# minions -- same trick as salt/nexus/network.sls, mirrored: both NICs are
# DHCP, so without this eth1's lease also installs an equal-metric default
# route via router-1. Dropping DHCP routes/DNS on it leaves just its on-link
# 10.30.30.0/24 route, which is all scraping needs.
grafana_hashibr_nic_netplan:
  file.managed:
    - name: /etc/netplan/60-grafana-hashibr-no-default.yaml
    - mode: '0600'
    - contents: |
        network:
          version: 2
          ethernets:
            eth1:
              dhcp4-overrides:
                use-routes: false
                use-dns: false

grafana_netplan_apply:
  cmd.run:
    - name: netplan apply
    - onchanges:
      - file: grafana_hashibr_nic_netplan
