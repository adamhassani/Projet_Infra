#!/bin/bash
set -e

# bascule le tunnel entre les modes : ip, udp, gretap
# le bridge (br0) reste en place, on change juste l'interface tunnel

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <ip|udp|gretap>"
    exit 1
fi

MODE=$1
echo "=== Phase 3 : Tunnel mode $MODE ==="

modprobe l2tp_eth 2>/dev/null || true
modprobe l2tp_ip  2>/dev/null || true
modprobe ip_gre   2>/dev/null || true

# suppression de l'ancien tunnel
for ns in R1 R2; do
    ip netns exec $ns ip l2tp del tunnel tunnel_id 1 2>/dev/null || true
    # gretap0 est reserve par le noyau donc on utilise gtun0
    ip netns exec $ns ip link del gtun0 2>/dev/null || true
done

if [ "$MODE" = "ip" ]; then
    ip netns exec R1 ip l2tp add tunnel tunnel_id 1 peer_tunnel_id 1 encap ip local 10.0.1.1 remote 10.0.3.2
    ip netns exec R1 ip l2tp add session name l2tpeth0 tunnel_id 1 session_id 1 peer_session_id 1
    ip netns exec R1 ip link set l2tpeth0 promisc on up

    ip netns exec R2 ip l2tp add tunnel tunnel_id 1 peer_tunnel_id 1 encap ip local 10.0.3.2 remote 10.0.1.1
    ip netns exec R2 ip l2tp add session name l2tpeth0 tunnel_id 1 session_id 1 peer_session_id 1
    ip netns exec R2 ip link set l2tpeth0 promisc on up
    IFACE="l2tpeth0"

elif [ "$MODE" = "udp" ]; then
    ip netns exec R1 ip l2tp add tunnel tunnel_id 1 peer_tunnel_id 1 encap udp local 10.0.1.1 remote 10.0.3.2 udp_sport 5000 udp_dport 5000
    ip netns exec R1 ip l2tp add session name l2tpeth0 tunnel_id 1 session_id 1 peer_session_id 1
    ip netns exec R1 ip link set l2tpeth0 promisc on up

    ip netns exec R2 ip l2tp add tunnel tunnel_id 1 peer_tunnel_id 1 encap udp local 10.0.3.2 remote 10.0.1.1 udp_sport 5000 udp_dport 5000
    ip netns exec R2 ip l2tp add session name l2tpeth0 tunnel_id 1 session_id 1 peer_session_id 1
    ip netns exec R2 ip link set l2tpeth0 promisc on up
    IFACE="l2tpeth0"

elif [ "$MODE" = "gretap" ]; then
    ip netns exec R1 ip link add name gtun0 type gretap local 10.0.1.1 remote 10.0.3.2 nopmtudisc
    ip netns exec R1 ip link set gtun0 promisc on up

    ip netns exec R2 ip link add name gtun0 type gretap local 10.0.3.2 remote 10.0.1.1 nopmtudisc
    ip netns exec R2 ip link set gtun0 promisc on up
    IFACE="gtun0"

else
    echo "mode invalide, choix : ip, udp, gretap"
    exit 1
fi

# attacher le nouveau tunnel au bridge existant
for ns in R1 R2; do
    ip netns exec $ns ip link set $IFACE master br0
    ip netns exec $ns bridge vlan add dev $IFACE vid 100
    ip netns exec $ns bridge vlan add dev $IFACE vid 200
done

echo "=== Phase 3 OK (mode $MODE) ==="
