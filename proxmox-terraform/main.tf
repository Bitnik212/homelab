locals {
  cluster_nodes = merge(
    { for i in range(1, var.vault_node_count + 1) : "vault-${i}" => { role = "vault" } },
    { for i in range(1, var.consul_node_count + 1) : "consul-${i}" => { role = "consul" } },
  )
}

resource "proxmox_virtual_environment_vm" "node" {
  for_each = local.cluster_nodes

  name      = each.key
  node_name = var.proxmox_node

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

  # Uncomment to grow the disk beyond the template's 15gb (shrinking is not
  # supported).
  # disk {
  #   datastore_id = var.vm_datastore_id
  #   interface    = "scsi0"
  #   size         = 30
  # }

  initialization {
    datastore_id = var.vm_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.cluster_bridge
  }
}
