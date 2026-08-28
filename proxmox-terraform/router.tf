resource "proxmox_virtual_environment_vm" "router" {
  name      = "router-1"
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

  initialization {
    datastore_id = var.vm_datastore_id

    # net0: WAN/management, on vmbr0 (DHCP)
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # net1: hashibr, static — router-1 is the gateway/DHCP server for this net
    ip_config {
      ipv4 {
        address = "10.30.30.1/24"
      }
    }
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = var.cluster_bridge
  }
}
