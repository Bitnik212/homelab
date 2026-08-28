# Static /etc/hosts pins on vm-myreels-bot.
#
# api.reels.bitt.app -> 127.0.0.1: convenience for host-level tools only
# (curl etc. from the VM's own shell, where 127.0.0.1 correctly means this
# box). Containers do NOT get a usable answer from this -- their own
# 127.0.0.1 is their own network namespace's loopback, not the VM's. The
# reels-bot container instead gets `extra_hosts: api.reels.bitt.app:
# host-gateway` in its own compose file (salt/myreels/files/reels-bot/
# docker-compose.yml), which resolves to the real VM interface.
#
# api.telegram.org / www.instagram.com: pinned to known-good real IPs to
# work around this network's DNS reliability issues (and this environment's
# history of ISP-level interference with Telegram/Instagram -- see
# router.splittunnel/amneziawg in pillar/router.sls). These ARE real
# routable addresses, not loopback, so Docker's embedded DNS -> host
# resolver -> /etc/hosts chain correctly hands them to containers too --
# no extra_hosts needed for these two.
#
# Caveat: static pins don't follow IP rotation the way DNS would. If the
# upstream service moves, these need manual updating.

myreels_hosts_reels_api_local:
  host.present:
    - ip: 127.0.0.1
    - names:
      - api.reels.bitt.app

myreels_hosts_telegram:
  host.present:
    - ip: 149.154.166.110
    - names:
      - api.telegram.org

myreels_hosts_instagram:
  host.present:
    - ip: 31.13.72.174
    - names:
      - www.instagram.com
