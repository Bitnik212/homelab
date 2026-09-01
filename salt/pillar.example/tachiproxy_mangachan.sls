# Copy into pillar_roots (e.g. ~/homelab/pillar/tachiproxy_mangachan.sls)
# and target it at the vm-tachiproxy-mangachan* minion in pillar top.sls.

tachiproxy_mangachan:
  db_password: 'CHANGEME'

  # vm-tachiproxy's LAN IP (proxmox-terraform/tachiproxy.tf) -- api/worker
  # route scrape traffic through its proxy (:8070) and manage revisions
  # through its API (:8100). Pinned to a static DHCP reservation on the LAN
  # router (10.20.10.1) via HOW_TO_MAKE_STATIC_DHCP_RECORD.md's script, so
  # this should stay stable -- but it's still a plain IP, not discovered,
  # so update it if the reservation is ever removed/changed.
  tachiproxy_host: '10.20.10.216'

  # ktor_log_level: 'DEBUG'
  # app_env: 'production'
  # graylog_http_input_url: 'https://http.input.graylog.bitt.app/gelf'

  # Disabled by default, matching mangachan's own local .env (which ships
  # these commented out too) -- flip s3_cache_enabled on once you're ready
  # to use it.
  # s3_cache_enabled: true
  # s3_cache_bucket: 'mangachan'
  # s3_cache_access_key: 'CHANGEME'
  # s3_cache_secret_key: 'CHANGEME'
  # s3_cache_endpoint: 'https://cdn.manga-one.bitt.app'
  # s3_cache_region: 'us-east-1'
  # s3_cache_public_base_url: 'https://cdn.manga.net.ru/mangachan'
  # s3_cache_key_prefix: ''
  # s3_cache_force_path_style: 'true'

  # proxyline_api_key: 'CHANGEME'
