# General NAT for the hashibr network, separate from split-tunnel.sh's
# AWG-specific fwmark-based MASQUERADE.
#
# Must NOT masquerade traffic destined for the local LAN (lan_cidr): the
# Salt master lives there, and NAT'ing that traffic hides minions' real
# 10.30.30.x source IPs, breaking the master's ability to route back to
# them. Only genuinely external traffic gets masqueraded.
#
# No -o <iface> restriction: split-tunnel.sh's pref 200 sends most external
# traffic via wg0, not eth0 (WAN) -- restricting this to -o eth0 leaves
# tunnel-routed hashibr traffic un-NAT'd, leaking a private, non-routable
# source IP into the tunnel with no way for anything to reply to it.

{%- set h = pillar.get('router', {}).get('hashibr', {}) %}
{%- set st = pillar.get('router', {}).get('splittunnel', {}) %}
{%- set subnet = h.get('subnet_cidr', '10.30.30.0/24') %}
{%- set wan_if = st.get('wan_if', 'eth0') %}
{%- set lan_cidr = st.get('lan_cidr', '') %}

# Remove the old rules from before this fix (both the original -o eth0-only
# form and the LAN-excluded -o eth0 form) if present -- either would still
# match (and masquerade only on eth0, or not at all on wg0) ahead of the
# corrected rule below.
hashibr_masquerade_cleanup_old:
  cmd.run:
    - name: >-
        iptables -t nat -D POSTROUTING -s {{ subnet }} -o {{ wan_if }} -j MASQUERADE 2>/dev/null;
        iptables -t nat -D POSTROUTING -s {{ subnet }} {% if lan_cidr %}! -d {{ lan_cidr }} {% endif %}-o {{ wan_if }} -j MASQUERADE 2>/dev/null;
        true
    - onlyif: >-
        iptables -t nat -C POSTROUTING -s {{ subnet }} -o {{ wan_if }} -j MASQUERADE 2>/dev/null ||
        iptables -t nat -C POSTROUTING -s {{ subnet }} {% if lan_cidr %}! -d {{ lan_cidr }} {% endif %}-o {{ wan_if }} -j MASQUERADE 2>/dev/null

hashibr_masquerade:
  cmd.run:
    - name: >-
        iptables -t nat -C POSTROUTING -s {{ subnet }} {% if lan_cidr %}! -d {{ lan_cidr }} {% endif %}-j MASQUERADE 2>/dev/null ||
        iptables -t nat -A POSTROUTING -s {{ subnet }} {% if lan_cidr %}! -d {{ lan_cidr }} {% endif %}-j MASQUERADE
    - require:
      - cmd: hashibr_masquerade_cleanup_old

# wg0's MTU (1420, WireGuard's own overhead) is smaller than hashibr
# clients' own NIC MTU (1500) -- without this, a hashibr client's TCP SYN
# advertises an MSS sized for 1500 and nothing downstream corrects it, so
# any segment that doesn't fit through the tunnel just stalls waiting on
# Path MTU Discovery that's commonly blackholed in the wild. Bit us as:
# small requests through the tunnel worked fine (fit in one segment either
# way), but a large download (e.g. a hashibr-side gitlab-runner's `wget` of
# a 130MB+ file, versus the same URL working fine run directly on
# router-1) hung. Locally-originated traffic from router-1 itself never
# hits this since the kernel already knows wg0's real MTU for its own
# sockets -- it's specifically a forwarded/NAT'd-traffic problem.
hashibr_forward_mss_clamp:
  cmd.run:
    - name: >-
        iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null ||
        iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Rules added via `iptables ... -A` above only live in the running
# nftables/iptables-nft ruleset -- nothing restores them on reboot (no
# startup_states configured on this minion, and unlike split-tunnel.sh
# this rule has no systemd unit re-applying it). That's exactly how this
# rule went missing after router-1's last reboot and cut hashibr off from
# the internet. iptables-persistent's netfilter-persistent.service loads
# /etc/iptables/rules.v4 back in on every boot, so save into it whenever
# the rule above changes.
iptables_persistent_debconf:
  debconf.set:
    - name: iptables-persistent
    - data:
        'iptables-persistent/autosave_v4': {'type': 'boolean', 'value': false}
        'iptables-persistent/autosave_v6': {'type': 'boolean', 'value': false}

iptables_persistent_pkg:
  pkg.installed:
    - name: iptables-persistent
    - require:
      - debconf: iptables_persistent_debconf

hashibr_masquerade_persist:
  cmd.run:
    - name: netfilter-persistent save
    - require:
      - pkg: iptables_persistent_pkg
    - onchanges:
      - cmd: hashibr_masquerade
      - cmd: hashibr_forward_mss_clamp
