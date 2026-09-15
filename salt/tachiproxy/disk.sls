# Revision payloads live on an NFS export from the manga-one NAS
# (10.20.10.81) rather than the local second disk Terraform used to attach
# as scsi1 (proxmox-terraform/tachiproxy.tf) -- that disk filled up (99gb,
# 100% used) and all its data has been migrated to the NFS export as of
# 2026-09-15 (verified file-for-file match before cutover). The scsi1 disk
# itself is still attached/mounted at /data/tachiproxy pending manual
# removal in Proxmox + Terraform; nothing here manages it anymore.
tachiproxy_nfs_common:
  pkg.installed:
    - name: nfs-common

tachiproxy_data_mount_point:
  file.directory:
    - name: /mnt/tachiproxy
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

tachiproxy_data_mounted:
  mount.mounted:
    - name: /mnt/tachiproxy
    - device: 10.20.10.81:/mnt/manga-one/tachiproxy
    - fstype: nfs
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - pkg: tachiproxy_nfs_common
      - file: tachiproxy_data_mount_point
