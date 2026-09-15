#!/usr/bin/env bash
# vm-mgmt (this host, the Salt master) needs to know how to route back to
# the hashibr network (10.30.30.0/24) via router-1 (10.20.10.140) on the
# LAN it shares with router-1's eth0. Without this, router-1's NAT no
# longer masks minions' real source IPs (see salt/router/nat.sls), but the
# master still has no route to reach them — replies just get dropped.
set -euo pipefail

# Immediate effect (does not survive reboot)
sudo ip route add 10.30.30.0/24 via 10.20.10.140 dev ens18

# Persist via a netplan drop-in (merges with the existing ens18 config)
sudo tee /etc/netplan/60-hashibr-route.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    ens18:
      routes:
        - to: 10.30.30.0/24
          via: 10.20.10.140
EOF
sudo netplan apply

echo "Done. Verify with: ip route show 10.30.30.0/24"
