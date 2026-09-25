# docker_pkgs is referenced by curseforge_apt_update's require_in below.
include:
  - docker

# vm-curseforge's vmbr0 NIC (net1 in proxmox-terraform/curseforge.tf) is
# there only to reach the manga-one NAS's NFS export on 10.20.10.0/24 --
# all other traffic goes out hashibr via router-1. Both NICs are DHCP, so
# without this the vmbr0 lease also installs a default route at the same
# metric as hashibr's (what vm-elk ended up with). Dropping DHCP routes/DNS
# on that NIC leaves just its on-link 10.20.10.0/24 route, which is all
# NFS needs.
#
# Matched by the name cloud-init's 50-cloud-init.yaml gives it (set-name
# eth1, net1 = second network_device); netplan merges this into that
# definition rather than replacing it.
curseforge_lan_nic_netplan:
  file.managed:
    - name: /etc/netplan/60-curseforge-lan-nfs-only.yaml
    - mode: '0600'
    - contents: |
        network:
          version: 2
          ethernets:
            eth1:
              dhcp4-overrides:
                use-routes: false
                use-dns: false

curseforge_netplan_apply:
  cmd.run:
    - name: netplan apply
    - onchanges:
      - file: curseforge_lan_nic_netplan

# The template's apt mirror (mirror.yandex.ru) times out from hashibr --
# router-1 sends hashibr egress out the AmneziaWG tunnel by default, and
# the mirror doesn't answer from there -- so docker-ce / nfs-common
# installs fail. archive.ubuntu.com is reachable either way.
curseforge_apt_mirror:
  file.replace:
    - name: /etc/apt/sources.list.d/ubuntu.sources
    - pattern: 'https://mirror\.yandex\.ru/ubuntu/'
    - repl: 'http://archive.ubuntu.com/ubuntu/'

curseforge_apt_update:
  cmd.run:
    - name: apt-get update
    - onchanges:
      - file: curseforge_apt_mirror
    - require_in:
      - pkg: docker_pkgs
      - pkg: curseforge_nfs_common
