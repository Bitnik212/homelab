# Nexus Repository (Community Edition) + an nginx caching front on the same
# VM -- pull-through cache for PyPI, npm and Maven Central artifacts
# (salt/nexus). Same NIC layout as vm-curseforge (curseforge.tf): net0 on
# hashibr carries the default route, so Nexus's upstream fetches go out
# router-1's xray tunnel; net1 on vmbr0 serves LAN clients directly and
# reaches the manga-one NAS's NFS export (10.20.10.81:/mnt/manga-one/nexus)
# where the blob store and nginx cache live. salt/nexus/network.sls strips
# net1's DHCP default route so there's a single default via router-1.
resource "proxmox_virtual_environment_vm" "nexus" {
  name      = "vm-nexus"
  node_name = var.proxmox_node

  # Free in both the live cluster and the PBS backup archive -- checked
  # with ./find-free-vmid.sh (see vm-elk.tf's vm_id comment for why).
  vm_id = 117

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = var.vm_datastore_id
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 4
  }

  # Sonatype's documented minimum for Nexus 3 (4 CPU / 8GB): the JVM's
  # default heap + direct memory alone are ~5.4GB.
  memory {
    dedicated = 8192
  }

  initialization {
    datastore_id = var.vm_datastore_id

    # net0: hashibr
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # net1: vmbr0, LAN clients + NFS
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
