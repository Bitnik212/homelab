#!/usr/bin/env bash
# Finds a VMID that's free across BOTH the live cluster (every node's
# qemu/lxc guests) and the PBS backup archive.
#
# Proxmox's own "next free ID" (what you get when a Terraform resource here
# omits vm_id, or when you run `pvesh cluster/nextid` / the "Create VM"
# wizard) only checks live guest configs. It happily hands out an ID that
# collides with a *backup* of a since-deleted VM -- that's what happened
# with vm-elk: the next free live ID was 115, but 115 already existed as a
# backup in the "backups" (PBS) storage. See vm-elk.tf's vm_id comment.
#
# Usage:
#   ./find-free-vmid.sh [range-start] [range-end]
#
#   range-start/range-end default to 100-999 (this cluster's VM/CT range;
#   IDs 1000+ and 9000+ are used for other things -- see the "used ids"
#   line printed on stderr).
#
# Prints the free VMID to stdout (only that, so it's safe to use as
# `vm_id = $(./find-free-vmid.sh)` / `terraform apply -var vm_id=$(...)`),
# and the full used-ID list to stderr for a sanity check.
#
# Credentials: reads proxmox_api_endpoint / proxmox_api_token /
# proxmox_tls_insecure out of terraform.tfvars in this directory. Override
# by exporting PROXMOX_API_ENDPOINT / PROXMOX_API_TOKEN /
# PROXMOX_TLS_INSECURE before running.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS="${SCRIPT_DIR}/terraform.tfvars"

tfvar() {
  grep -E "^$1[[:space:]]*=" "${TFVARS}" | head -n1 | sed -E 's/^[^=]+=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'
}

if [[ -z "${PROXMOX_API_ENDPOINT:-}" || -z "${PROXMOX_API_TOKEN:-}" ]]; then
  if [[ ! -f "${TFVARS}" ]]; then
    echo "ERROR: ${TFVARS} not found and PROXMOX_API_ENDPOINT/PROXMOX_API_TOKEN not set" >&2
    exit 1
  fi
fi

PROXMOX_API_ENDPOINT="${PROXMOX_API_ENDPOINT:-$(tfvar proxmox_api_endpoint)}"
PROXMOX_API_TOKEN="${PROXMOX_API_TOKEN:-$(tfvar proxmox_api_token)}"
PROXMOX_TLS_INSECURE="${PROXMOX_TLS_INSECURE:-$(tfvar proxmox_tls_insecure)}"
PROXMOX_API_ENDPOINT="${PROXMOX_API_ENDPOINT%/}"

RANGE_START="${1:-100}"
RANGE_END="${2:-999}"

CURL_OPTS=(-s --max-time 15 -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}")
[[ "${PROXMOX_TLS_INSECURE}" == "true" ]] && CURL_OPTS+=(-k)

api() { curl "${CURL_OPTS[@]}" "${PROXMOX_API_ENDPOINT}$1"; }

# Live guests (qemu + lxc), every node, one call.
live_ids="$(api /cluster/resources?type=vm | python3 -c '
import json, sys
data = json.load(sys.stdin)["data"]
print("\n".join(str(r["vmid"]) for r in data))
')"

# Backup-capable storages, deduped: shared storages (PBS, NFS, etc.) are the
# same content regardless of which node you ask, so query each shared
# storage once; per-node (unshared) storages get queried per node.
mapfile -t backup_storages < <(api /cluster/resources?type=storage | python3 -c '
import json, sys
data = json.load(sys.stdin)["data"]
seen = set()
for r in data:
    if "backup" not in r.get("content", "").split(","):
        continue
    node = r["node"]
    storage = r["storage"]
    key = storage if r.get("shared") else node + "/" + storage
    if key in seen:
        continue
    seen.add(key)
    print(node, storage)
')

backup_ids=""
for entry in "${backup_storages[@]}"; do
  node="${entry%% *}"
  storage="${entry#* }"
  ids="$(api "/nodes/${node}/storage/${storage}/content" | python3 -c '
import json, sys
data = json.load(sys.stdin)["data"]
print("\n".join(str(i["vmid"]) for i in data if "vmid" in i))
' 2>/dev/null || true)"
  backup_ids+=$'\n'"${ids}"
done

used_ids="$(printf '%s\n%s\n' "${live_ids}" "${backup_ids}" | grep -E '^[0-9]+$' | sort -nu)"

free_id=""
for ((id = RANGE_START; id <= RANGE_END; id++)); do
  if ! grep -qx "${id}" <<<"${used_ids}"; then
    free_id="${id}"
    break
  fi
done

if [[ -z "${free_id}" ]]; then
  echo "No free VMID found in range ${RANGE_START}-${RANGE_END}" >&2
  exit 1
fi

echo "Used IDs (live + backups): $(tr '\n' ' ' <<<"${used_ids}")" >&2
echo "${free_id}"
