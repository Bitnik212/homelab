# On vmbr0 (default LAN, 10.20.10.0/24), not hashibr -- DHCP-assigned like
# vm-tachiproxy.
resource "proxmox_virtual_environment_vm" "tachiproxy_mangachan" {
  name      = "vm-tachiproxy-mangachan"
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

  # postgres + api + worker (both JVM/Ktor) on one box.
  memory {
    dedicated = 4096
  }

  # Second disk for postgres data (salt/tachiproxy_mangachan/disk.sls formats
  # and mounts it at /data/tachiproxy-mangachan) -- kept off the template's
  # 15gb root disk, which the catalog DB filled up. Same pattern as
  # vm-tachiproxy's scsi1 data disk (proxmox-terraform/tachiproxy.tf).
  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi1"
    size         = 30
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
