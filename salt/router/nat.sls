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
