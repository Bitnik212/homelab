# Copy into pillar_roots (e.g. ~/homelab/pillar/router.sls) and target it
# at the router-* minion in pillar top.sls.

router:
  dns:
    allowed_networks:
      - 10.0.0.0/8
      - 192.168.0.0/16
      - 172.16.0.0/12
    # Forward to an internal DNS server on your LAN to inherit its records,
    # or use public resolvers (e.g. 1.1.1.1, 9.9.9.9) if you don't have one.
    forwarders:
      - 10.20.10.100
    local_records: []
    #  - {name: 'vault.home.', value: '10.10.10.51'}

  # AmneziaWG client (router.amneziawg, wg0 with Table = off) + sing-box tun
  # (router.singbox), which dials out bound to wg0. The highstate refuses to
  # render until endpoint is set.
  amneziawg:
    private_key: ''
    address: ''             # e.g. '10.8.0.4/32, fdcc:ad94:bacf:61a4::cafe:4/128'
    mtu: 1420
    dns: ''                 # e.g. '1.1.1.1, 2606:4700:4700::1111'
    Jc: 0
    Jmin: 0
    Jmax: 0
    S1: 0
    S2: 0
    H1: 0
    H2: 0
    H3: 0
    H4: 0
    server_public_key: ''
    preshared_key: ''
    # IPv4:port, not a hostname -- the IP is excluded from tun0 so wg0's own
    # packets aren't looped back into the tunnel.
    endpoint: ''
    persistent_keepalive: 0
    # Public IP router.publicip_check expects to see; defaults to the
    # endpoint's. Set it if the server egresses from a different address.
    expected_egress_ip: ''

  singbox:
    mode: full              # full: everything via proxy except RU/private; selected: only proxy_cidrs via proxy
    direct_ru: True         # full mode: geoip-ru destinations go direct (WAN)
    proxy_cidrs: []         # required for mode: selected, e.g. ['1.1.1.0/24']
    ssh_client_ip: ''       # optional extra /32 kept off the tunnel (private ranges always are)
    # Replies from these local ports stay on WAN instead of tun0 (services
    # router-1 itself answers on for non-LAN clients).
    incoming_bypass_ports: [22, 80, 443]
    # >0 arms a "stop sing-box after N seconds" timer on every config
    # change, as a remote-safety net (setup-xray-singbox.sh used 60). Cancel
    # with `systemctl stop rollback-singbox.timer`, then set back to 0.
    rollback_after_seconds: 0

  # Still read by router.nat (wan_if, lan_cidr).
  splittunnel:
    wan_if: ''    # e.g. ens18 / eth0
    lan_cidr: ''  # e.g. 10.20.10.0/24

  # router-1's second NIC — gateway/DHCP/NAT for the cluster bridge
  # (proxmox-terraform's cluster_bridge var, e.g. hashibr).
  hashibr:
    interface: ''       # e.g. eth1 — the NIC actually on that bridge
    subnet_cidr: '10.30.30.0/24'
    network: '10.30.30.0'
    netmask: '255.255.255.0'
    gateway: '10.30.30.1'  # must match router-1's static address on that NIC
    dns: '10.30.30.1'      # router-1's own unbound
    range_start: '10.30.30.10'
    range_end: '10.30.30.250'

  # Plain-HTTP proxy_pass into hashibr-only VMs. No TLS here yet -- add
  # certbot + a listen 443 block per vhost once that's wanted.
  proxy:
    vhosts: []
    #  - server_name: 'api.example.com'
    #    upstream: '10.30.30.20:8080'
