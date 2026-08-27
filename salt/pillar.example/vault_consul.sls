# Copy this into your pillar_roots (e.g. /srv/pillar/vault_consul.sls) and
# target it at the vault-*/consul-* minions in pillar top.sls.
#
# Generate the gossip key with: consul keygen
#
# consul_version/vault_version pin the apt package to an exact version via
# /etc/apt/preferences.d. To upgrade later, bump the value here and re-run
# state.apply on the affected minions. Check available exact versions with:
#   curl -s https://apt.releases.hashicorp.com/dists/noble/main/binary-amd64/Packages | grep -A1 '^Package: consul$'
#
# Note: Vault's apt repo has no 1.22.x build yet (Consul and Vault version
# lines have diverged) — 1.21.4-1 is the newest available as of 2026-08-27.
consul_version: '1.22.7-1'
vault_version: '1.21.4-1'

consul:
  datacenter: dc1
  bootstrap_expect: 3
  retry_join:
    - consul-1
    - consul-2
    - consul-3
  encrypt_key: ''

vault:
  cluster_nodes:
    - vault-1
    - vault-2
    - vault-3
