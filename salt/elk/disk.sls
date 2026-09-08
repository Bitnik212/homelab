# Formats and mounts the 300gb second disk Terraform attaches as scsi1
# (proxmox-terraform/vm-elk.tf). Both disks are present from first boot
# (like vm-tachiproxy, unlike vm-tachiproxy-mangachan's hot-plugged one) --
# but unlike tachiproxy/tachiproxy_mangachan's disk.sls, which hardcode a
# /dev/sdX path verified via `lsblk` on their own already-running VMs, this
# VM doesn't exist yet, so there's nothing to verify a guess against.
# Instead of guessing which of /dev/sda|/dev/sdb the kernel hands to which
# disk (on the deployed VM the 300gb data disk actually came up as sda and
# the 15gb boot disk as sdb -- reversed from what scsi0/scsi1 would suggest),
# this resolves the data disk at apply time as "whichever top-level TYPE=disk
# block device isn't the boot disk's parent" -- restricted to TYPE=disk since
# plain `lsblk -dn -o NAME` also lists the cloud-init ISO's rom devices
# (sr0/sr1) -- and fails loudly if that isn't exactly one device. Mounted by
# filesystem LABEL so it survives reboots renumbering devices either way.

elk_data_mount_point:
  file.directory:
    - name: /data/elk
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

elk_data_disk_format:
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
        mkfs.ext4 -L elk-data "/dev/$candidates"
    - shell: /bin/bash
    - unless: blkid -L elk-data
    - require:
      - file: elk_data_mount_point

elk_data_mounted:
  mount.mounted:
    - name: /data/elk
    - device: LABEL=elk-data
    - fstype: ext4
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - cmd: elk_data_disk_format
