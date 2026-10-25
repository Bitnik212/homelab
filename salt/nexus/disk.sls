# Nexus's blob store and nginx's proxy_cache both live on an NFS export
# from the manga-one NAS (10.20.10.81), same NAS as vm-curseforge's
# artifacts (salt/curseforge/disk.sls), reached over the vmbr0 NIC (see
# nexus.network). Nexus's own embedded DB stays on a local docker volume
# (files/docker-compose.yml) -- Sonatype doesn't support the DB on NFS,
# only blob stores.
include:
  - nexus.network

nexus_nfs_common:
  pkg.installed:
    - name: nfs-common

nexus_storage_mounted:
  mount.mounted:
    - name: /mnt/nexus
    - device: 10.20.10.81:/mnt/manga-one/nexus
    - fstype: nfs
    - opts: defaults
    - persist: True
    - mkmnt: True
    - require:
      - pkg: nexus_nfs_common
      - cmd: nexus_netplan_apply

# The sonatype/nexus3 image runs as uid/gid 200 (no matching user on the
# host, hence install -d rather than file.directory's user:). Relies on the
# export allowing root to chown (maproot=root, like curseforge's).
nexus_blobs_dir:
  cmd.run:
    - name: install -d -m 0750 -o 200 -g 200 /mnt/nexus/blobs
    - unless: test "$(stat -c %u:%g /mnt/nexus/blobs 2>/dev/null)" = 200:200
    - require:
      - mount: nexus_storage_mounted

nexus_nginx_cache_dir:
  file.directory:
    - name: /mnt/nexus/nginx-cache
    - user: www-data
    - group: www-data
    - mode: '0750'
    - require:
      - mount: nexus_storage_mounted
      - pkg: nexus_nginx_pkg
