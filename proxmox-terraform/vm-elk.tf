# On vmbr0 (default LAN, 10.20.10.0/24), DHCP-assigned like vm-tachiproxy --
# plus a second NIC on hashibr (also DHCP, via router-1's isc-dhcp-server)
# purely as an alternate egress: router-1's split-tunnel.sh sends anything
# hashibr-sourced out via the AmneziaWG tunnel by default (see
# salt/elk/hashibr_route.sls), which vm-elk uses to reach epr.elastic.co /
# *.elastic.co -- same workaround as the HashiCorp CDN geo-block noted in
# pillar/router.sls's splittunnel comment. No HA: single-node Elasticsearch
# + Kibana log sink.
resource "proxmox_virtual_environment_vm" "elk" {
  name      = "vm-elk"
  node_name = var.proxmox_node

  # Pinned explicitly: the provider's auto-assigned "next free ID" only
  # checks live VM/CT configs, not the PBS backup archive (storage
  # "backups"), which still holds vmid 115 (a deleted VM's backup) --
  # letting it auto-assign collided with that. 109 is free in both the
  # live cluster (checked across all nodes) and the backup content list --
  # verified with ./find-free-vmid.sh, which future VMs here should use too.
  vm_id = 109

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

  # Elasticsearch + Kibana on one box -- ES wants headroom for JVM heap
  # plus OS page cache, well above the bare cluster nodes' 2048MB.
  memory {
    dedicated = 8192
  }

  # No explicit scsi0 block -- the template's own root disk already lands on
  # vm-data via clone.datastore_id above (same as every other VM here);
  # redeclaring it as a disk block would risk provisioning a second,
  # superfluous disk alongside it instead of "pinning" the existing one.

  # Second disk for the Elasticsearch data path (salt/elk/disk.sls formats
  # and mounts it at /data/elk) -- on the faster vm-data-ssd datastore since
  # ES is I/O-sensitive, and kept off the root disk since indices are
  # expected to grow unbounded. Same pattern as vm-tachiproxy's scsi1 data
  # disk (proxmox-terraform/tachiproxy.tf).
  disk {
    datastore_id = "vm-data-ssd"
    interface    = "scsi1"
    size         = 300
  }

  initialization {
    datastore_id = var.vm_datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

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
