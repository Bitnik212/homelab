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
