# On vmbr0 (default LAN, 10.20.10.0/24), DHCP-assigned like vm-tachiproxy /
# vm-tachiproxy-mangachan. Single container (ghcr.io/gremten/psb:main, a
# Next.js app) with its sqlite research DB bind-mounted on the template's
# root disk -- no second data disk, unlike the Postgres/Elasticsearch VMs,
# since the DB file is tiny.
resource "proxmox_virtual_environment_vm" "gremten" {
  name      = "vm-gremten"
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

  # Lightweight Next.js app -- same as the bare cluster nodes' default.
  memory {
    dedicated = 2048
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
    bridge = "vmbr0"
  }
}
