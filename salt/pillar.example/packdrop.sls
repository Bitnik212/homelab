# Copy into pillar_roots (e.g. ~/homelab/pillar/packdrop.sls) and target
# it at the vm-curseforge minion in pillar top.sls.

packdrop:
  secret_key: 'change-this-secret'
  # Mail.ru SMTP login; the password is an app password from mail.ru's
  # security settings, not the account password.
  email_host_user: ''
  email_host_password: ''
  default_from_email: 'Packdrop <packdrop@example.com>'
