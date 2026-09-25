# hashibr-first, like vm-myreels-bot: net0 sits on hashibr (DHCP from
# router-1, default route through it) and public access to the app comes
# from router-1's nginx proxy_pass over hashibr (pillar/router.sls
# "proxy.vhosts"). net1 on vmbr0 exists ONLY to reach the manga-one NAS's
# NFS export (10.20.10.81:/mnt/manga-one/curseforge) for artifact storage --
# hashibr can't reach it, since router-1 deliberately doesn't NAT
# hashibr->LAN traffic (salt/router/nat.sls) and the NAS has no route back
# to 10.30.30.0/24. salt/curseforge/network.sls strips the DHCP default
# route off net1 so it doesn't end up with two equal-metric defaults the
# way vm-elk has (vm-elk.tf).
resource "proxmox_virtual_environment_vm" "curseforge" {
  name      = "vm-curseforge"
  node_name = var.proxmox_node

  # Free in both the live cluster and the PBS backup archive -- checked
  # with ./find-free-vmid.sh (see vm-elk.tf's vm_id comment for why).
  vm_id = 116

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

  # Single Django runserver container; artifacts live on NFS, not in RAM.
  memory {
    dedicated = 2048
  }

  initialization {
    datastore_id = var.vm_datastore_id

    # net0: hashibr
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # net1: vmbr0, NFS only
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.cluster_bridge
  }

  network_device {
    bridge = "vmbr0"
  }
}
