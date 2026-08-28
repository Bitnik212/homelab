# Copy into pillar_roots (e.g. ~/homelab/pillar/myreels.sls) and target it
# at the vm-myreels-bot* minion in pillar top.sls.

myreels:
  reels_api:
    proxyline_api_key: 'CHANGEME'
    s3_access_key: 'CHANGEME'
    s3_bucket: 'myreels'
    s3_endpoint_url: 'https://s3.yandexcloud.net'
    s3_secret_key: 'CHANGEME'
    ktor_log_level: 'WARNING'
    db_url: 'jdbc:postgresql://db:5432/reels'
    sentry_auth_token: 'CHANGEME'
    sentry_dsn: 'CHANGEME'

  db:
    user: 'reels_watcher'
    password: 'CHANGEME'

  reels_bot:
    reels_api_url: 'https://api.reels.bitt.app'
    telegram_bot_token: 'CHANGEME'
    telegram_bot_username: 'reelsbittbot'
    pocketbase_hostname: 'myreels.pocketbase.moe'
