#!/bin/bash
set -e

# accès internet pour les vlans via R1 + dnsmasq intelligent (PC3/PC4 via R2)
# a. switch Internet + machine hote
# b. NAT iptables sur R1
# c. verif que PC3 passe par R1
# d. dnsmasq redirige PC3/PC4 vers R2

echo "=== Phase 6 : Accès Internet ==="

# trouver l'interface internet du host
REAL_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
[ -z "$REAL_IFACE" ] && { echo "Pas d'accès internet sur la machine hote."; exit 1; }
echo "[*] Interface hote : $REAL_IFACE"

# nettoyage
ip link del host-internet  2>/dev/null || true
ip link del ovs-inet-host  2>/dev/null || true
ovs-vsctl del-br ovs-internet 2>/dev/null || true
ip netns exec R_A ip link del eth2   2>/dev/null || true
ip netns exec R2 ip link del br0.100 2>/dev/null || true
ip netns exec R2 ip link del br0.200 2>/dev/null || true

# --- a. switch Internet ---
echo "[*] a. Création du switch Internet"
ovs-vsctl add-br ovs-internet
ovs-vsctl set bridge ovs-internet fail_mode=standalone

# R_A rejoint le switch Internet via eth2 (10.87.0.1/24)
ip link add veth-ra-inet type veth peer name ra-eth2
ip link set ra-eth2 netns R_A name eth2
ip netns exec R_A ip link set eth2 up
ip netns exec R_A ip addr add 10.87.0.1/24 dev eth2
ip link set veth-ra-inet up
ovs-vsctl add-port ovs-internet veth-ra-inet

# machine hote sur le switch Internet (10.87.0.254/24)
ip link add host-internet type veth peer name ovs-inet-host
ip link set host-internet up
ip link set ovs-inet-host up
ovs-vsctl add-port ovs-internet ovs-inet-host
ip addr add 10.87.0.254/24 dev host-internet 2>/dev/null || true

# routes
ip netns exec R_A ip route add default via 10.87.0.254 2>/dev/null || true
ip netns exec R_B ip route add default via 10.0.2.1    2>/dev/null || true
# route retour : le host doit savoir renvoyer les reponses vers les routeurs
ip route add 10.0.0.0/8 via 10.87.0.1 2>/dev/null || true

# forwarding + NAT sur le host
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -C POSTROUTING -s 10.0.0.0/8 -o $REAL_IFACE -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o $REAL_IFACE -j MASQUERADE
iptables -C FORWARD -i host-internet -o $REAL_IFACE -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i host-internet -o $REAL_IFACE -j ACCEPT
iptables -C FORWARD -i $REAL_IFACE -o host-internet -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i $REAL_IFACE -o host-internet -m state --state RELATED,ESTABLISHED -j ACCEPT


# --- b. NAT sur R1 pour les deux VLANs ---
echo "[*] b. NAT iptables sur R1"
ip netns exec R1 iptables -t nat -F
ip netns exec R1 iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE
ip netns exec R1 iptables -t nat -A POSTROUTING -s 192.168.200.0/24 -o eth0 -j MASQUERADE

# --- c. test : PC1 et PC3 passent par R1 ---
echo ""
echo "[*] c. Test accès Internet"
if ip netns exec PC1 ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "    PC1 (cote R1) -> 8.8.8.8 : OK"
else
    echo "    PC1 -> 8.8.8.8 : ECHEC"
fi
if ip netns exec PC3 ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "    PC3 (cote R2, via tunnel -> R1) -> 8.8.8.8 : OK"
else
    echo "    PC3 -> 8.8.8.8 : ECHEC"
fi

# --- d. dnsmasq intelligent : PC3/PC4 utilisent R2 comme gateway ---
echo ""
echo "[*] d. dnsmasq intelligent -> PC3/PC4 gateway = R2"

# donner des IPs VLAN a R2 (192.168.100.253 et 192.168.200.253)
ip netns exec R2 bridge vlan add dev br0 vid 100 self 2>/dev/null || true
ip netns exec R2 bridge vlan add dev br0 vid 200 self 2>/dev/null || true

ip netns exec R2 ip link add link br0 name br0.100 type vlan id 100 2>/dev/null || true
ip netns exec R2 ip addr add 192.168.100.253/24 dev br0.100 2>/dev/null || true
ip netns exec R2 ip link set br0.100 up

ip netns exec R2 ip link add link br0 name br0.200 type vlan id 200 2>/dev/null || true
ip netns exec R2 ip addr add 192.168.200.253/24 dev br0.200 2>/dev/null || true
ip netns exec R2 ip link set br0.200 up

ip netns exec R2 sysctl -w net.ipv4.ip_forward=1 >/dev/null
ip netns exec R2 iptables -t nat -F 2>/dev/null || true
ip netns exec R2 iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE
ip netns exec R2 iptables -t nat -A POSTROUTING -s 192.168.200.0/24 -o eth0 -j MASQUERADE

# recuperer les MACs de PC3 et PC4 pour dnsmasq dhcp-host
MAC_PC3=$(ip netns exec PC3 ip link show eth0 | grep link/ether | awk '{print $2}')
MAC_PC4=$(ip netns exec PC4 ip link show eth0 | grep link/ether | awk '{print $2}')
echo "    PC3 MAC : $MAC_PC3 -> GW 192.168.100.253 (R2)"
echo "    PC4 MAC : $MAC_PC4 -> GW 192.168.200.253 (R2)"

# arret des anciens dnsmasq
[ -f /tmp/dnsmasq-vlan100.pid ] && kill "$(cat /tmp/dnsmasq-vlan100.pid)" 2>/dev/null || true
[ -f /tmp/dnsmasq-vlan200.pid ] && kill "$(cat /tmp/dnsmasq-vlan200.pid)" 2>/dev/null || true
rm -f /tmp/dnsmasq-vlan*.leases /tmp/dnsmasq-vlan*.pid

# VLAN 100 : par defaut GW=R1, mais PC3 recoit GW=R2 via tag dnsmasq
ip netns exec R1 dnsmasq \
    --interface=br0.100 \
    --bind-interfaces \
    --port=0 \
    --dhcp-range=192.168.100.100,192.168.100.200,255.255.255.0,1h \
    --dhcp-option=option:router,192.168.100.254 \
    --dhcp-host=$MAC_PC3,set:via-r2 \
    --dhcp-option=tag:via-r2,option:router,192.168.100.253 \
    --dhcp-option=option:dns-server,1.1.1.1 \
    --no-resolv \
    --dhcp-leasefile=/tmp/dnsmasq-vlan100.leases \
    --pid-file=/tmp/dnsmasq-vlan100.pid

# VLAN 200 : pareil, PC4 recoit GW=R2
ip netns exec R1 dnsmasq \
    --interface=br0.200 \
    --bind-interfaces \
    --port=0 \
    --dhcp-range=192.168.200.100,192.168.200.200,255.255.255.0,1h \
    --dhcp-option=option:router,192.168.200.254 \
    --dhcp-host=$MAC_PC4,set:via-r2 \
    --dhcp-option=tag:via-r2,option:router,192.168.200.253 \
    --dhcp-option=option:dns-server,1.1.1.1 \
    --no-resolv \
    --dhcp-leasefile=/tmp/dnsmasq-vlan200.leases \
    --pid-file=/tmp/dnsmasq-vlan200.pid

# relancer DHCP sur les 4 PCs pour appliquer les nouvelles options
for ns in PC1 PC2 PC3 PC4; do
    ip netns exec $ns ip addr flush dev eth0 2>/dev/null || true
    ip netns exec $ns dhclient -1 eth0
done

echo ""
echo "[*] Gateways après DHCP intelligent :"
for ns in PC1 PC2 PC3 PC4; do
    GW=$(ip netns exec $ns ip route show default 2>/dev/null | awk '{print $3}')
    echo "  $ns -> GW=$GW"
done

echo ""
echo "[*] Test final PC3 (via R2) -> Internet"
if ip netns exec PC3 ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "    PC3 -> 8.8.8.8 via R2 : OK"
else
    echo "    PC3 -> 8.8.8.8 via R2 : ECHEC"
fi

echo "=== Phase 6 OK ==="
