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
