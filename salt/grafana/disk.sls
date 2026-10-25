# Formats and mounts the 30gb second disk Terraform attaches as scsi1
# (proxmox-terraform/grafana.tf). Same approach as elk/disk.sls: the data
# disk is resolved at apply time as "whichever top-level TYPE=disk block
# device isn't the boot disk's parent", failing loudly if that isn't
# exactly one device, and mounted by filesystem LABEL so it survives
# reboots renumbering devices.

grafana_data_mount_point:
  file.directory:
    - name: /data/grafana
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

grafana_data_disk_format:
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
        mkfs.ext4 -L grafana-data "/dev/$candidates"
    - shell: /bin/bash
    - unless: blkid -L grafana-data
    - require:
      - file: grafana_data_mount_point

grafana_data_mounted:
  mount.mounted:
    - name: /data/grafana
    - device: LABEL=grafana-data
    - fstype: ext4
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - cmd: grafana_data_disk_format
