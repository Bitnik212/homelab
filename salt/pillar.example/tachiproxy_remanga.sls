# Copy into pillar_roots (e.g. ~/homelab/pillar/tachiproxy_remanga.sls)
# and target it at the vm-tachiproxy-remanga* minion in pillar top.sls.

tachiproxy_remanga:
  db_password: 'CHANGEME'

  # vm-tachiproxy's LAN IP -- see pillar.example/tachiproxy_mangachan.sls.
  tachiproxy_host: '10.20.10.216'

  # app_env: 'production'
  # graylog_http_input_url: 'https://http.input.graylog.bitt.app/gelf'
  # source_client_log_level: 'NONE'
  # source_request_interval_millis: 1000

# vm-elk's LAN IP and the filebeat_writer_remanga ES user password (see
# pillar.example/elk.sls) -- consumed by the filebeat container in
# salt/tachiproxy_remanga/files/docker-compose.yml.
elk:
  host: ''                        # e.g. 10.20.10.220 (vm-elk's static DHCP reservation)
  filebeat_writer_password: 'CHANGEME'
