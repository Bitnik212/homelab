# Copy into pillar_roots (e.g. ~/homelab/pillar/grafana.sls) and target it
# at the vm-grafana minion in pillar top.sls.

grafana:
  admin_password: 'CHANGEME'

  # One entry per minion running node_exporter. address is the IP
  # vm-grafana scrapes it on -- a 10.20.10.x LAN address where the minion
  # has one, otherwise its hashibr 10.30.30.x one (reachable over
  # vm-grafana's hashibr NIC). Plain IPs, not discovered, so update them if
  # a minion's DHCP reservation changes.
  node_targets:
    - {name: 'vm-elk', address: '10.20.10.220'}
    - {name: 'vm-myreels-bot', address: '10.30.30.16'}
    # - {name: 'vm-example', address: '10.20.10.x', port: 9100}
