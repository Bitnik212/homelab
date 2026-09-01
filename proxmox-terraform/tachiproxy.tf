# On vmbr0 (default LAN, 10.20.10.0/24), not hashibr -- DHCP-assigned like
# the management NIC on router-1's net0.
resource "proxmox_virtual_environment_vm" "tachiproxy" {
  name      = "vm-tachiproxy"
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

  # postgres + api (FastAPI/cron) + proxy (mitmproxy) on one box.
  memory {
    dedicated = 4096
  }

  # Second disk for revision payload storage (salt/tachiproxy/disk.sls
  # formats and mounts it at /data/tachiproxy) -- kept off the template's
  # 15gb root disk since revisions are expected to grow unbounded.
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
