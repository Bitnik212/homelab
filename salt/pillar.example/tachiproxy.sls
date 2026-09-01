# Copy into pillar_roots (e.g. ~/homelab/pillar/tachiproxy.sls) and target it
# at the vm-tachiproxy* minion in pillar top.sls.

tachiproxy:
  db_password: 'CHANGEME'
  api_token: 'CHANGEME'

  # Default is the built-in StaticProxyProvider with an empty upstream list
  # (no proxies configured yet). Switch to ProxyLineProvider once you have
  # upstream credentials:
  # proxy_provider: 'version_proxy.providers.proxyline:ProxyLineProvider'
  # proxy_provider_options: '{"api_key": "CHANGEME", "protocol": "http", "tags": ["automenu"]}'
