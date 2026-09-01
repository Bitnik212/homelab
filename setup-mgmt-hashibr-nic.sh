#!/usr/bin/env bash
# vm-mgmt moved to the one-main Proxmox node and got ens20 on hashibr
# directly. That makes the earlier static-route-via-router-1 workaround
# (60-hashibr-route.yaml) obsolete — this box now reaches 10.30.30.0/24
# natively. .2 is free (DHCP pool is .10-.250, router-1 itself is .1).
set -euo pipefail

sudo rm -f /etc/netplan/60-hashibr-route.yaml

sudo tee /etc/netplan/61-hashibr-ens20.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    ens20:
      dhcp4: false
      addresses:
        - 10.30.30.2/24
EOF
sudo netplan apply

echo "Done. Verify with: ip addr show ens20"
