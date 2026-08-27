# Copy into pillar_roots (e.g. ~/homelab/pillar/router.sls) and target it
# at the router-* minion in pillar top.sls.

router:
  dns:
    allowed_networks:
      - 10.0.0.0/8
      - 192.168.0.0/16
      - 172.16.0.0/12
    forwarders:
      - 1.1.1.1
      - 9.9.9.9
    local_records: []
    #  - {name: 'vault.home.', value: '10.10.10.51'}

  amneziawg:
    private_key: ''       # this client's private key
    address: ''            # e.g. 10.7.0.63/24 (assigned by your AWG server)
    dns: ''                # optional, e.g. 1.1.1.1
    # Obfuscation params must match your AWG server's config exactly:
    Jc: ''
    Jmin: ''
    Jmax: ''
    S1: ''
    S2: ''
    H1: ''
    H2: ''
    H3: ''
    H4: ''

    server_public_key: ''
    preshared_key: ''
    endpoint: ''            # host:port of your AmneziaWG server
    persistent_keepalive: 25

    # AllowedIPs defaults to 0.0.0.0/0, ::/0 for cryptokey routing. Table =
    # off means awg-quick installs no routes automatically — router.splittunnel
    # (split-tunnel.sh) owns the "vpn" table / ip rules instead.

  splittunnel:
    wan_if: ''    # e.g. ens18 / eth0
    wan_gw: ''    # WAN gateway IP
    wg_endpoint_ip: ''  # resolved IP of your AWG server's endpoint host
    rollback_after_seconds: 0
