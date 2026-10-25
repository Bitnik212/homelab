# Patroni-managed Postgres, one instance pinned to each physical Proxmox
# node (one-main, one-data, two-data) via node_name -- this is a real
# 3-host Proxmox cluster, not the single var.proxmox_node every other VM in
# this repo so far lands on.
#
# Single NIC per node, on the dedicated bridge in var.postgres_mgmt_bridge
# (10.10.10.0/24, DHCP). That one network carries mgmt/Salt/SSH traffic AND
# Patroni's own Raft consensus AND Postgres streaming replication -- no
# separate sync-only network, by design. No vmbr0 NIC at all: these are db
# VMs and must not reach the internet. The firewall rules below are
# belt-and-suspenders on top of that -- confirm the dedicated bridge
# actually doesn't route to WAN once its name is known, don't rely on the
# firewall rules alone.
#
# DCS: Patroni's built-in Raft implementation (pysyncobj), not Consul/etcd
# -- keeps this cluster fully self-contained rather than depending on the
# existing Consul cluster over hashibr (which defaults to tunneled internet
# egress via router-1's split-tunnel, see pillar/router.sls). Same
# reasoning as Vault's own "storage raft" here rather than Consul
# (salt/vault/files/vault.hcl.jinja).
locals {
  postgres_nodes = toset(["one-main", "one-data", "two-data"])
}

resource "proxmox_virtual_environment_vm" "postgres" {
  for_each = local.postgres_nodes

  name      = "vm-postgres-${each.key}"
  node_name = each.key

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.vm_datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  # Postgres data directory -- kept off the template's root disk, same
  # pattern as vm-tachiproxy-mangachan's scsi1 (proxmox-terraform/tachiproxy-mangachan.tf).
  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi1"
    size         = var.postgres_data_disk_size
  }

  initialization {
    datastore_id = var.vm_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge   = var.postgres_mgmt_bridge[each.key]
    firewall = true
  }
}

# Blocks each Postgres node from reaching anything outside the dedicated
# 10.10.10.0/24 network. NOT verified against the installed bpg/proxmox
# provider (0.111.1) yet -- this repo hasn't used
# proxmox_virtual_environment_firewall_rules before, so double-check the
# rule block's exact arguments in that provider version before the first
# apply.
resource "proxmox_virtual_environment_firewall_rules" "postgres" {
  for_each = local.postgres_nodes

  node_name = each.key
  vm_id     = proxmox_virtual_environment_vm.postgres[each.key].vm_id

  rule {
    action = "ACCEPT"
    type   = "out"
    dest   = "10.10.10.0/24"
  }

  rule {
    action = "DROP"
    type   = "out"
  }
}
