# Formats and mounts the 30gb second disk Terraform attaches as scsi1
# (proxmox-terraform/tachiproxy.tf). This VM boots from sata0 (see the
# boot_order in Terraform's state), and virtio-scsi disks enumerate before
# SATA ones in-kernel -- so on this VM the *data* disk comes up as /dev/sda
# and the *OS root* disk as /dev/sdb (sdb1 ESP, sdb2 /boot, sdb3 LVM root).
# That's the reverse of the naive "scsi0/first disk is root" assumption;
# verified via `lsblk` after first boot. Re-check with `lsblk` if the boot
# disk interface or attached-disk count ever changes -- the guard below
# stops a flipped assumption from ever formatting the OS disk again.
# Mounted by filesystem LABEL rather than /dev/sda so it survives further
# device renumbering.
{%- set data_disk = '/dev/sda' %}

tachiproxy_data_mount_point:
  file.directory:
    - name: /data/tachiproxy
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

tachiproxy_data_disk_is_not_boot_disk:
  cmd.run:
    - name: test "$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)")" != "{{ data_disk[5:] }}"
    - require:
      - file: tachiproxy_data_mount_point

tachiproxy_data_format:
  cmd.run:
    - name: mkfs.ext4 -L tachiproxy-data {{ data_disk }}
    - unless: blkid {{ data_disk }}
    - require:
      - cmd: tachiproxy_data_disk_is_not_boot_disk

tachiproxy_data_mounted:
  mount.mounted:
    - name: /data/tachiproxy
    - device: LABEL=tachiproxy-data
    - fstype: ext4
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - cmd: tachiproxy_data_format
