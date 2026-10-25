# Prometheus + Grafana (salt/grafana) -- scrapes every minion's
# node_exporter (:9100) and serves the dashboards at grafana.bitt.app.
# net0 on vmbr0 (default LAN, DHCP) carries the default route and reaches
# the LAN minions; net1 on hashibr exists only to scrape hashibr-only
# minions (vm-myreels-bot) -- salt/grafana/network.sls strips its DHCP
# default route so there's a single default via 10.20.10.1.
resource "proxmox_virtual_environment_vm" "grafana" {
  name      = "vm-grafana"
  node_name = var.proxmox_node

  # Free in both the live cluster and the PBS backup archive -- checked
  # with ./find-free-vmid.sh (see vm-elk.tf's vm_id comment for why).
  vm_id = 167

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
    dedicated = 4096
  }

  # Second disk for Prometheus's TSDB and Grafana's sqlite DB
  # (salt/grafana/disk.sls formats and mounts it at /data/grafana) -- kept
  # off the template's 15gb root disk since the TSDB grows with retention.
  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi1"
    size         = 30
  }

  initialization {
    datastore_id = var.vm_datastore_id

    # net0: vmbr0
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # net1: hashibr, scrape-only
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
    bridge = var.cluster_bridge
  }
}
