ipv4_forwarding:
  sysctl.present:
    - name: net.ipv4.ip_forward
    - value: 1

# wg0's MTU (1420) is below the standard 1500, and PMTU discovery for
# forwarded (not locally-originated) connections routinely black-holes —
# path routers drop ICMP frag-needed messages, so oversized TCP segments
# (e.g. TLS handshakes) just hang instead of getting fragmented or
# rejected. Clamp MSS on the way into wg0 so this never comes up.
wg0_mss_clamp:
  cmd.run:
    - name: >-
        iptables -t mangle -C FORWARD -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null ||
        iptables -t mangle -A FORWARD -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
