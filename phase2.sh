#!/bin/bash
set -e

# bridge linux sur R1 et R2 + tunnel L2TPv3 (mode IP)
# les deux bridges relient le LAN (eth1) et le tunnel

echo "=== Phase 2 : Bridge + Tunnel L2TPv3 ==="

modprobe l2tp_ip    2>/dev/null || true
modprobe l2tp_eth   2>/dev/null || true
# br_netfilter permet a iptables de voir le trafic bridgé (necessaire pour TCPMSS)
modprobe br_netfilter 2>/dev/null || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>/dev/null || true

# nettoyage
for ns in R1 R2; do
    ip netns exec $ns ip l2tp del tunnel tunnel_id 1 2>/dev/null || true
    ip netns exec $ns ip link del br0 2>/dev/null || true
done

# bridge avec vlan filtering sur R1 et R2
for ns in R1 R2; do
    ip netns exec $ns ip link add name br0 type bridge vlan_filtering 1 stp_state 0 forward_delay 0
    ip netns exec $ns ip link set br0 up

    # eth1 rejoint le bridge (interface vers OVS)
    ip netns exec $ns ip link set eth1 promisc on
    ip netns exec $ns ip link set eth1 master br0
    ip netns exec $ns bridge vlan add dev eth1 vid 100
    ip netns exec $ns bridge vlan add dev eth1 vid 200
done

# tunnel L2TPv3 encapsulation IP entre R1 (10.0.1.1) et R2 (10.0.3.2)
ip netns exec R1 ip l2tp add tunnel tunnel_id 1 peer_tunnel_id 1 encap ip local 10.0.1.1 remote 10.0.3.2
ip netns exec R1 ip l2tp add session name l2tpeth0 tunnel_id 1 session_id 1 peer_session_id 1
ip netns exec R1 ip link set l2tpeth0 up

ip netns exec R2 ip l2tp add tunnel tunnel_id 1 peer_tunnel_id 1 encap ip local 10.0.3.2 remote 10.0.1.1
ip netns exec R2 ip l2tp add session name l2tpeth0 tunnel_id 1 session_id 1 peer_session_id 1
ip netns exec R2 ip link set l2tpeth0 up

# le tunnel rejoint le bridge
for ns in R1 R2; do
    ip netns exec $ns ip link set l2tpeth0 promisc on
    ip netns exec $ns ip link set l2tpeth0 master br0
    ip netns exec $ns bridge vlan add dev l2tpeth0 vid 100
    ip netns exec $ns bridge vlan add dev l2tpeth0 vid 200
done

# IPs de gateway sur R1 via sous-interfaces vlan du bridge
# faut autoriser les vlans sur le port local du bridge (cpu port) d'abord
ip netns exec R1 bridge vlan add dev br0 vid 100 self
ip netns exec R1 bridge vlan add dev br0 vid 200 self

ip netns exec R1 ip link add link br0 name br0.100 type vlan id 100
ip netns exec R1 ip addr add 192.168.100.254/24 dev br0.100
ip netns exec R1 ip link set br0.100 up

ip netns exec R1 ip link add link br0 name br0.200 type vlan id 200
ip netns exec R1 ip addr add 192.168.200.254/24 dev br0.200
ip netns exec R1 ip link set br0.200 up

ip netns exec R1 sysctl -w net.ipv4.ip_forward=1 >/dev/null

# le tunnel reduit le MTU (1458), le clamping MSS evite que les gros paquets TCP soient droppes
ip netns exec R1 iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip netns exec R2 iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# routes par defaut sur les PCs
ip netns exec PC1 ip route add default via 192.168.100.254
ip netns exec PC2 ip route add default via 192.168.200.254
ip netns exec PC3 ip route add default via 192.168.100.254
ip netns exec PC4 ip route add default via 192.168.200.254

# le tunnel L2TPv3 a un MTU reduit (1458), on ajuste les PCs pour eviter
# que les gros paquets TCP soient droppes dans le tunnel
for ns in PC1 PC2 PC3 PC4; do
    ip netns exec $ns ip link set eth0 mtu 1400
done

echo "=== Phase 2 OK ==="
