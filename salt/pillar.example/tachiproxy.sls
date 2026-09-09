# Copy into pillar_roots (e.g. ~/homelab/pillar/tachiproxy.sls) and target it
# at the vm-tachiproxy* minion in pillar top.sls.

tachiproxy:
  db_password: 'CHANGEME'

  # Unset by default -- the API is unauthenticated unless this is set (see
  # files/env.jinja: '# API_TOKEN=change-me' when absent).
  # api_token: 'CHANGEME'

  # Default is the built-in StaticProxyProvider with an empty upstream list
  # (no proxies configured -- every request 502s). Switch to ProxyLineProvider
  # once you have upstream credentials:
  # proxy_provider: 'version_proxy.providers.proxyline:ProxyLineProvider'
  # proxyline_api_key: 'CHANGEME'
  # proxy_provider_options: '{"protocol": "http", "tags": ["automenu"]}'

  # Full-tunnel AmneziaWG client (salt/tachiproxy/amneziawg.sls) -- for
  # when the ISP blocks outbound HTTP proxy connections directly, so all
  # egress needs to go through a VPN instead of just select destinations.
  amneziawg:
    private_key: ''       # this client's private key
    address: ''            # e.g. 10.7.0.65/24 (assigned by your AWG server)
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
    # off means awg-quick installs no routes on its own --
    # tachiproxy.splittunnel (below) owns the "vpn" table / ip rules
    # instead, same shape as router.amneziawg/router.splittunnel.

  # salt/tachiproxy/splittunnel.sls -- policy routing so wg0 is the default
  # route for everything except local/management traffic.
  splittunnel:
    wan_if: ''    # e.g. eth0 -- this box's LAN NIC
    wan_gw: ''    # LAN gateway IP
    lan_cidr: ''  # e.g. 10.20.10.0/24 -- keeps local/Salt traffic off the tunnel
    wg_endpoint_ip: ''  # resolved IP of your AWG server's endpoint host
