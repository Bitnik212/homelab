# Copy into pillar_roots (e.g. ~/homelab/pillar/curseforge.sls) and target
# it at the vm-curseforge minion in pillar top.sls.

curseforge:
  # From https://console.curseforge.com
  api_key: ''
  django_secret_key: 'change-this-secret'
