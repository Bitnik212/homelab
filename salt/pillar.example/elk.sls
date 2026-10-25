# Copy into pillar_roots (e.g. ~/homelab/pillar/elk.sls) and target it at
# the vm-elk minion in pillar top.sls.

elk:
  # xpack security has to be on for Fleet to work at all ("Kibana security
  # must be enabled to use Fleet") -- these are the elastic superuser and
  # kibana_system service account passwords for the single-node stack.
  elastic_password: 'CHANGEME'
  kibana_password: 'CHANGEME'

  # Kibana generates random ones at every startup if unset, which works but
  # invalidates sessions/encrypted saved objects (Fleet's agent policies,
  # enrollment tokens, etc.) on every container restart -- pin real values
  # (32+ hex chars, e.g. `openssl rand -hex 16`) so Fleet data survives a
  # `docker compose restart`.
  encryptedsavedobjects_key: 'CHANGEME'
  security_encryption_key: 'CHANGEME'
  reporting_encryption_key: 'CHANGEME'

  # Password for the filebeat_writer ES user (salt/elk/app.sls creates it,
  # scoped to only tachiproxy-logs-*) -- must match pillar/tachiproxy.sls's
  # elk.filebeat_writer_password.
  filebeat_writer_password: 'CHANGEME'

  # Same, but for the filebeat_writer_mangachan ES user (scoped to only
  # tachiproxy-mangachan-logs-*) -- must match
  # pillar/tachiproxy_mangachan.sls's elk.filebeat_writer_password.
  filebeat_writer_mangachan_password: 'CHANGEME'

  # Same, but for the filebeat_writer_lv ES user (scoped to only
  # lv_vpn-logs-*) -- lv isn't a Salt minion in this repo (headscale-only host,
  # reachable from vm-elk), so this password is also copied by hand into
  # filebeat's config on that host rather than templated via pillar.
  filebeat_writer_lv_password: 'CHANGEME'
