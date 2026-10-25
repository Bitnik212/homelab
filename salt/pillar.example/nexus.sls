# Copy into pillar_roots (e.g. ~/homelab/pillar/nexus.sls) and target it
# at the vm-nexus minion in pillar top.sls.

nexus:
  # Set as Nexus's admin password on first apply (replacing the random one
  # it generates); salt/nexus/files/bootstrap.sh.jinja logs in with it on
  # every apply after that. No single quotes (templated into a '...' string).
  admin_password: 'CHANGEME'

  # sonatype/nexus3 tag. Not pulled on every apply -- bump this to upgrade.
  image_tag: 'latest'

  # nginx proxy_cache size cap on the NAS export (/mnt/nexus/nginx-cache).
  nginx_cache_max_size: '50g'
