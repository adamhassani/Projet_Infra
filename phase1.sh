#!/bin/bash
set -e

# topologie de base : namespaces, ovs, liens veth, vlans

echo "=== Phase 1 : Topologie ==="

# nettoyage pour relancer proprement
# OVS d'abord, puis les veths host explicitement, puis les namespaces
ovs-vsctl del-br ovs1 2>/dev/null || true
ovs-vsctl del-br ovs2 2>/dev/null || true

for iface in veth-ovs1-pc1 veth-ovs1-pc2 veth-ovs1-r1 veth-ovs2-pc3 veth-ovs2-pc4 veth-ovs2-r2; do
    ip link del $iface 2>/dev/null || true
done

for ns in R1 R2 R_A R_B PC1 PC2 PC3 PC4; do
    ip netns del $ns 2>/dev/null || true
done

# creation des namespaces
for ns in R1 R2 R_A R_B PC1 PC2 PC3 PC4; do
    ip netns add $ns
    ip netns exec $ns ip link set lo up
done

# les deux switchs OVS (un par site)
ovs-vsctl add-br ovs1
ovs-vsctl add-br ovs2

# connecte un namespace a un switch ovs via une paire veth
connect_ns_to_ovs() {
    local ns=$1 if_ns=$2 ovs=$3 if_host=$4
    ip link add $if_host type veth peer name veth-$ns-$if_ns
    ip link set veth-$ns-$if_ns netns $ns name $if_ns
    ip netns exec $ns ip link set $if_ns up
    ip link set $if_host up
    ovs-vsctl add-port $ovs $if_host
}

# site 1 : PC1, PC2 et R1 sur ovs1
connect_ns_to_ovs PC1 eth0 ovs1 veth-ovs1-pc1
connect_ns_to_ovs PC2 eth0 ovs1 veth-ovs1-pc2
connect_ns_to_ovs R1  eth1 ovs1 veth-ovs1-r1

# site 2 : PC3, PC4 et R2 sur ovs2
connect_ns_to_ovs PC3 eth0 ovs2 veth-ovs2-pc3
connect_ns_to_ovs PC4 eth0 ovs2 veth-ovs2-pc4
connect_ns_to_ovs R2  eth1 ovs2 veth-ovs2-r2

# WAN : R1 <-> R_A <-> R_B <-> R2
ip link add veth-r1   type veth peer name veth-ra-1
ip link set veth-r1   netns R1  name eth0
ip link set veth-ra-1 netns R_A name eth0
ip netns exec R1  ip link set eth0 up
ip netns exec R_A ip link set eth0 up

ip link add veth-ra-2 type veth peer name veth-rb-1
ip link set veth-ra-2 netns R_A name eth1
ip link set veth-rb-1 netns R_B name eth0
ip netns exec R_A ip link set eth1 up
ip netns exec R_B ip link set eth0 up

ip link add veth-rb-2 type veth peer name veth-r2
ip link set veth-rb-2 netns R_B name eth1
ip link set veth-r2   netns R2  name eth0
ip netns exec R_B ip link set eth1 up
ip netns exec R2  ip link set eth0 up

# adresses IP du WAN
ip netns exec R1  ip addr add 10.0.1.1/24 dev eth0
ip netns exec R1  ip route add default via 10.0.1.2

ip netns exec R_A ip addr add 10.0.1.2/24 dev eth0
ip netns exec R_A ip addr add 10.0.2.1/24 dev eth1
ip netns exec R_A sysctl -w net.ipv4.ip_forward=1 >/dev/null
ip netns exec R_A ip route add 10.0.3.0/24 via 10.0.2.2

ip netns exec R_B ip addr add 10.0.2.2/24 dev eth0
ip netns exec R_B ip addr add 10.0.3.1/24 dev eth1
ip netns exec R_B sysctl -w net.ipv4.ip_forward=1 >/dev/null
ip netns exec R_B ip route add 10.0.1.0/24 via 10.0.2.1

ip netns exec R2  ip addr add 10.0.3.2/24 dev eth0
ip netns exec R2  ip route add default via 10.0.3.1

# vlans OVS : trunk vers les routeurs, access vers les PCs
ovs-vsctl set port veth-ovs1-r1 trunks=100,200
ovs-vsctl set port veth-ovs2-r2 trunks=100,200

ovs-vsctl set port veth-ovs1-pc1 tag=100
ovs-vsctl set port veth-ovs2-pc3 tag=100

ovs-vsctl set port veth-ovs1-pc2 tag=200
ovs-vsctl set port veth-ovs2-pc4 tag=200

# IPs statiques sur les PCs (remplacees par DHCP si on lance phase4)
ip netns exec PC1 ip addr add 192.168.100.10/24 dev eth0
ip netns exec PC2 ip addr add 192.168.200.20/24 dev eth0
ip netns exec PC3 ip addr add 192.168.100.30/24 dev eth0
ip netns exec PC4 ip addr add 192.168.200.40/24 dev eth0



ip netns exec R1 ip link add link eth1 name eth1.100 type vlan id 100
ip netns exec R1 ip link set dev eth1.100 up
ip netns exec R1 ip addr add 192.168.100.254/24 dev eth1.100

echo "=== Phase 1 OK ==="
