# Downloaded CurseForge artifacts live on an NFS export from the manga-one
# NAS (10.20.10.81), same NAS as vm-tachiproxy's payloads
# (salt/tachiproxy/disk.sls). Reached over the vmbr0 NIC -- see
# curseforge.network. The sqlite DB stays on a local docker volume
# instead (files/docker-compose.yml): sqlite's locking isn't safe on NFS.
#
# The export directory is root-owned 0755 with maproot=root on the NAS, so
# the container runs as root (files/docker-compose.yml) to write to it.
include:
  - curseforge.network

curseforge_nfs_common:
  pkg.installed:
    - name: nfs-common

curseforge_storage_mounted:
  mount.mounted:
    - name: /mnt/curseforge
    - device: 10.20.10.81:/mnt/manga-one/curseforge
    - fstype: nfs
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - pkg: curseforge_nfs_common
      - cmd: curseforge_netplan_apply
