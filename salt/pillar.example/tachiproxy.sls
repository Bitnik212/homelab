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
  #
  # proxyline_api_key above is also read by salt/tachiproxy/proxyroute.sls
  # to route the active upstream proxy IPs via the AmneziaWG tunnel below
  # (needs a real key, not the commented-out default).

  # Proxy API panel/registry (salt/tachiproxy/proxyapi.sls), on :8200.
  proxyapi:
    secret_key: 'CHANGEME'          # Django SECRET_KEY, long random string
    allowed_hosts: 'proxy.bitt.app,10.20.10.216,localhost'  # unset = '*'
    csrf_trusted_origins: 'https://proxy.bitt.app'  # also turns on TRUST_X_FORWARDED_PROTO
    # proxyline_api_key: ''         # defaults to tachiproxy.proxyline_api_key
    # proxyline_sync_cron_minute: '*/30'
    # health_interval: 10           # seconds
    # health_timeout: 5             # seconds, keep below the interval
    # health_url: 'https://www.gstatic.com/generate_204'
    # health_concurrency: 100
    # health_batch: 500

  # AmneziaWG client (salt/tachiproxy/amneziawg.sls) -- for when the ISP
  # blocks outbound HTTP proxy connections directly. Table = off:
  # tachiproxy.proxyroute routes only the active upstream proxy IPs onto
  # this interface, nothing else uses it by default.
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

    # AllowedIPs defaults to 0.0.0.0/0, ::/0 for cryptokey routing (only
    # relevant for the destinations tachiproxy.proxyroute actually routes
    # onto this interface -- Table = off, so awg-quick installs no routes
    # of its own, and there's no split-tunnel/default-route state here).

# vm-elk's LAN IP and the filebeat_writer ES user password (see
# pillar.example/elk.sls) -- consumed by the filebeat container in
# salt/tachiproxy/files/docker-compose.yml, which ships this host's docker
# container logs into Kibana.
elk:
  host: ''                        # e.g. 10.20.10.220 (vm-elk's static DHCP reservation)
  filebeat_writer_password: 'CHANGEME'
