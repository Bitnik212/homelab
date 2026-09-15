#!/usr/bin/env bash
# setup-salt-master.sh was run under sudo, so ~/homelab/pillar ended up
# owned by root instead of bit. Hand it back.
set -euo pipefail

sudo chown -R bit:bit /home/bit/homelab/pillar

echo "Done."
