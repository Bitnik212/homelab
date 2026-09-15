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

  # The scsi1 second disk this VM used for revision payload storage
  # (/data/tachiproxy) is gone -- it filled up (99gb) and payloads moved to
  # an NFS export from the manga-one NAS instead (salt/tachiproxy/disk.sls
  # mounts it at /mnt/tachiproxy). Migration verified file-for-file on
  # 2026-09-15 before this disk was detached in Proxmox.
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
