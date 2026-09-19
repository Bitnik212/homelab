# Revision payloads live on an NFS export from the manga-one NAS
# (10.20.10.81) rather than the local second disk Terraform used to attach
# as scsi1 (proxmox-terraform/tachiproxy.tf) -- that disk filled up (99gb,
# 100% used) and all its data has been migrated to the NFS export as of
# 2026-09-15 (verified file-for-file match before cutover). The scsi1 disk
# has been unlinked from the VM in Proxmox directly (API unlink, not
# Terraform -- dropping the `disk` block alone doesn't detach it, confirmed
# via the node's API showing scsi1 still fully attached after that change
# was applied); it now sits as unused0 with the underlying volume kept
# around pending a manual decision to purge it. This unmounts the old local
# mount and drops it from fstab so nothing tries to remount a device that
# no longer exists on the VM.
tachiproxy_data_unmounted:
  mount.unmounted:
    - name: /data/tachiproxy
    - device: LABEL=tachiproxy-data
    - fstype: ext4
    - persist: True

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
