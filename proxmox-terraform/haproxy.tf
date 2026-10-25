# Fronts the Patroni-managed Postgres cluster (postgres.tf) -- routes
# client connections to whichever node Patroni's REST API (:8008) currently
# reports as leader (Patroni's documented haproxy pattern: http-check
# against /leader, non-leaders marked down).
#
# Not a db VM itself, so unlike postgres.tf's nodes it gets a normal LAN
# NIC (vmbr0, DHCP) too -- otherwise nothing outside the isolated
# 10.10.10.0/24 network could ever reach Postgres through it. Second NIC on
# the same dedicated bridge as the Postgres nodes, to reach the backends
# and their Patroni API.
resource "proxmox_virtual_environment_vm" "haproxy" {
  name      = "vm-haproxy"
  node_name = var.haproxy_node

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
    dedicated = 1024
  }

  initialization {
    datastore_id = var.vm_datastore_id

    # net0: LAN, vmbr0, DHCP -- clients reach Postgres through here.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # net1: dedicated Postgres/Patroni network, DHCP.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = var.postgres_mgmt_bridge[var.haproxy_node]
  }
}
