# docker_pkgs is referenced by nexus_apt_update's require_in below.
include:
  - docker

# Same NIC layout as vm-curseforge (salt/curseforge/network.sls): net0 on
# hashibr carries the default route (so Nexus's upstream fetches go out
# router-1's xray tunnel), net1 on vmbr0 is for LAN clients and the NAS's
# NFS export only. Both NICs are DHCP, so without this net1's lease also
# installs an equal-metric default route. Dropping DHCP routes/DNS on it
# leaves just its on-link 10.20.10.0/24 route, which is all LAN clients and
# NFS need.
#
# Matched by the name cloud-init's 50-cloud-init.yaml gives it (set-name
# eth1, net1 = second network_device); netplan merges this into that
# definition rather than replacing it.
nexus_lan_nic_netplan:
  file.managed:
    - name: /etc/netplan/60-nexus-lan-no-default.yaml
    - mode: '0600'
    - contents: |
        network:
          version: 2
          ethernets:
            eth1:
              dhcp4-overrides:
                use-routes: false
                use-dns: false

nexus_netplan_apply:
  cmd.run:
    - name: netplan apply
    - onchanges:
      - file: nexus_lan_nic_netplan

# Same template apt mirror problem as vm-curseforge (mirror.yandex.ru
# timing out from hashibr) -- archive.ubuntu.com is reachable either way.
nexus_apt_mirror:
  file.replace:
    - name: /etc/apt/sources.list.d/ubuntu.sources
    - pattern: 'https://mirror\.yandex\.ru/ubuntu/'
    - repl: 'http://archive.ubuntu.com/ubuntu/'

nexus_apt_update:
  cmd.run:
    - name: apt-get update
    - onchanges:
      - file: nexus_apt_mirror
    - require_in:
      - pkg: docker_pkgs
      - pkg: nexus_nfs_common
      - pkg: nexus_nginx_pkg
