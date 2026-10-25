# Same shape as vm-tachiproxy-mangachan (tachiproxy-mangachan.tf), for
# source/remanga: on vmbr0 (default LAN, 10.20.10.0/24), DHCP-assigned,
# with postgres + api + worker on one box.
resource "proxmox_virtual_environment_vm" "tachiproxy_remanga" {
  name      = "vm-tachiproxy-remanga"
  node_name = var.proxmox_node

  # Free in both the live cluster and the PBS backup archive -- checked
  # with ./find-free-vmid.sh (see vm-elk.tf's vm_id comment for why).
  vm_id = 144

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

  # Second disk for postgres data (salt/tachiproxy_remanga/disk.sls formats
  # and mounts it at /data/tachiproxy-remanga) -- kept off the template's
  # 15gb root disk from the start, since mangachan's catalog DB filled it.
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
