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
  'vm-tachiproxy*':
    - tachiproxy
