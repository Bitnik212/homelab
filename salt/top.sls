base:
  'vault-*':
    - consul.client
    - vault
  'consul-*':
    - consul
  'router-*':
    - router
  'vm-myreels-bot*':
    - myreels
  # Exact match -- 'vm-tachiproxy*' would also swallow vm-tachiproxy-mangachan.
  'vm-tachiproxy':
    - tachiproxy
  'vm-tachiproxy-mangachan*':
    - tachiproxy_mangachan
  'vm-vpn':
    - vpn
