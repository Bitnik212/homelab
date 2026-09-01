#!/usr/bin/env bash
# The salt-master process runs as system user "salt", which isn't a member
# of the "bit" group — so it can't traverse into /home/bit (drwxr-x---) to
# reach ~/homelab/salt or ~/homelab/pillar. Add it to the group and restart.
set -euo pipefail

sudo usermod -aG bit salt
sudo systemctl restart salt-master

echo "Done. Verify with: sudo salt 'vault-1' pillar.items"
