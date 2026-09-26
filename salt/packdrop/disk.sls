# Packdrop's MEDIA_ROOT (built mods.zip files under zips/, stored mod icons
# under icons/) lives on an NFS export from the manga-one NAS, next to
# curseforge's (salt/curseforge/disk.sls) and reached the same way, over the
# vmbr0 NIC. The sqlite DB stays on a local docker volume
# (files/docker-compose.yml): sqlite's locking isn't safe on NFS.
#
# curseforge.disk brings in nfs-common and the vmbr0 netplan fix.
include:
  - curseforge.disk

packdrop_storage_mounted:
  mount.mounted:
    - name: /mnt/packdrop
    - device: 10.20.10.81:/mnt/manga-one/packdrop
    - fstype: nfs
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - pkg: curseforge_nfs_common
      - cmd: curseforge_netplan_apply

# The prod image runs as uid 1000 "app" (nginx serves the zips too, via
# X-Accel-Redirect), so hand the export root to that uid rather than run
# the container as root the way curseforge does. Works over NFS thanks to
# maproot=root on the NAS.
packdrop_storage_owner:
  file.directory:
    - name: /mnt/packdrop
    - user: 1000
    - group: 1000
    - mode: '0755'
    - require:
      - mount: packdrop_storage_mounted
