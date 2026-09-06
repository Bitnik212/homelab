# Formats and mounts the 30gb second disk Terraform attaches as scsi1
# (proxmox-terraform/tachiproxy-mangachan.tf). Unlike vm-tachiproxy's scsi1
# disk (tachiproxy/disk.sls, where it enumerates as /dev/sda ahead of the
# sata0 root at /dev/sdb because both disks were present at boot), this disk
# was hot-plugged into an already-running VM -- sata0 had already claimed
# /dev/sda by then, so the new disk came up appended as /dev/sdb instead
# (verified via `lsblk`). If this VM is ever rebooted, virtio-scsi-before-
# sata enumeration may flip that back to matching vm-tachiproxy's layout --
# the guard below stops a flipped assumption from ever formatting the OS
# disk, so re-check with `lsblk` if it ever fires. Mounted by filesystem
# LABEL rather than /dev/sdb so it survives further device renumbering.
{%- set data_disk = '/dev/sdb' %}

tachiproxy_mangachan_data_mount_point:
  file.directory:
    - name: /data/tachiproxy-mangachan
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

# Skipped once the data disk is already mounted: after a reboot flips device
# enumeration (see note above), the hardcoded {{ data_disk }} guess can itself
# become the boot disk, which would fail this check even though the real data
# disk (now under a different /dev path) is already formatted and mounted
# fine. Nothing left to protect at that point, so don't block on it.
tachiproxy_mangachan_data_disk_is_not_boot_disk:
  cmd.run:
    - name: test "$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)")" != "{{ data_disk[5:] }}"
    - unless: mountpoint -q /data/tachiproxy-mangachan
    - require:
      - file: tachiproxy_mangachan_data_mount_point

# ext4 labels are capped at 16 bytes -- "tachiproxy-mangachan-data" (25)
# silently truncates to "tachiproxy-manga", breaking the LABEL= lookup
# below, so this stays short.
tachiproxy_mangachan_data_format:
  cmd.run:
    - name: mkfs.ext4 -L mangachan-data {{ data_disk }}
    - unless: blkid {{ data_disk }}
    - require:
      - cmd: tachiproxy_mangachan_data_disk_is_not_boot_disk

tachiproxy_mangachan_data_mounted:
  mount.mounted:
    - name: /data/tachiproxy-mangachan
    - device: LABEL=mangachan-data
    - fstype: ext4
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - cmd: tachiproxy_mangachan_data_format
