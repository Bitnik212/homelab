# Replaces the manually-created vm-myreels-bot: this is a fresh VM,
# fully managed by Salt from first boot. The old manually-created VM is
# being decommissioned separately once this one is verified working.
#
# hashibr-only by design: this VM has no WAN-facing NIC. Public access to
# reels-api/imgproxy comes from router-1's nginx proxy_pass over hashibr
# (see salt/router/nginx.sls), matching how vault/consul nodes are reached.
resource "proxmox_virtual_environment_vm" "myreels_bot" {
  name      = "vm-myreels-bot"
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

  # Runs reels-api + postgres + reels-bot + redis + imgproxy on one box --
  # given more headroom than the bare cluster nodes' 2048MB.
  memory {
    dedicated = 4096
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
    bridge = var.cluster_bridge
  }
}
