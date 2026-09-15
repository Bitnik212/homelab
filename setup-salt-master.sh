#!/usr/bin/env bash
# Points the local salt-master at ~/homelab/salt and ~/homelab/pillar,
# seeds the pillar dir from the example, and restarts salt-master.
set -euo pipefail

HOMELAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SALT_DIR="${HOMELAB_DIR}/salt"
PILLAR_DIR="${HOMELAB_DIR}/pillar"

mkdir -p "${PILLAR_DIR}"

cat > "${PILLAR_DIR}/top.sls" <<EOF
base:
  'vault-*':
    - vault_consul
  'consul-*':
    - vault_consul
EOF

cp "${SALT_DIR}/pillar.example/vault_consul.sls" "${PILLAR_DIR}/vault_consul.sls"

sudo tee /etc/salt/master.d/homelab.conf > /dev/null <<EOF
file_roots:
  base:
    - ${SALT_DIR}

pillar_roots:
  base:
    - ${PILLAR_DIR}
EOF

sudo systemctl restart salt-master

echo "Done. Verify with: sudo salt '*' test.ping"
