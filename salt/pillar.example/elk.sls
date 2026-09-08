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
