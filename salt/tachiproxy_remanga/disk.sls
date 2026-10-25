# Formats and mounts the 30gb second disk Terraform attaches as scsi1
# (proxmox-terraform/tachiproxy-remanga.tf). Present from first boot, so
# unlike tachiproxy_mangachan/disk.sls's hardcoded /dev/sdb this resolves the
# data disk at apply time the same way elk/disk.sls does: "whichever
# top-level TYPE=disk block device isn't the boot disk's parent", failing
# loudly if that isn't exactly one device. Mounted by filesystem LABEL so it
# survives reboots renumbering devices either way.

tachiproxy_remanga_data_mount_point:
  file.directory:
    - name: /data/tachiproxy-remanga
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

# ext4 labels are capped at 16 bytes -- see tachiproxy_mangachan/disk.sls.
tachiproxy_remanga_data_format:
  cmd.run:
    - name: |
        set -euo pipefail
        boot_disk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)")
        candidates=$(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" { print $1 }' | grep -vx "$boot_disk")
        count=$(echo "$candidates" | wc -l)
        if [ "$count" -ne 1 ]; then
          echo "expected exactly one non-boot disk, got: $candidates" >&2
          exit 1
        fi
        mkfs.ext4 -L remanga-data "/dev/$candidates"
    - shell: /bin/bash
    - unless: blkid -L remanga-data
    - require:
      - file: tachiproxy_remanga_data_mount_point

tachiproxy_remanga_data_mounted:
  mount.mounted:
    - name: /data/tachiproxy-remanga
    - device: LABEL=remanga-data
    - fstype: ext4
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - cmd: tachiproxy_remanga_data_format
