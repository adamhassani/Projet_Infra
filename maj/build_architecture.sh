#!/bin/bash -x

# Graphe : INFRA_PROJET_LAB (Question 1)

# 1. Créer les différents namespaces
ip netns add RouteurA
ip netns add RouteurB
ip netns add Routeur1
ip netns add Routeur2
ip netns add Poste1
ip netns add Poste2
ip netns add Poste3
ip netns add Poste4

# 2. Créer les switches (Open vSwitch)
ovs-vsctl add-br Internet
ovs-vsctl add-br resC
ovs-vsctl add-br resB
ovs-vsctl add-br resD
ovs-vsctl add-br resE

# ==========================================
# CONFIGURATION DU COEUR DE RÉSEAU (INTERNET)
# ==========================================

# RouteurA
ip link add rA-eth0 type veth peer name net-rA
ip link add rA-eth1 type veth peer name resC-rA
ip link set rA-eth0 netns RouteurA
ip link set rA-eth1 netns RouteurA
ovs-vsctl add-port Internet net-rA
ovs-vsctl add-port resC resC-rA
ip link set dev net-rA up
ip link set dev resC-rA up

ip netns exec RouteurA ip link set dev lo up
ip netns exec RouteurA ip link set dev rA-eth0 up
ip netns exec RouteurA ip link set dev rA-eth1 up
ip netns exec RouteurA ip a add dev rA-eth0 10.87.0.1/24
ip netns exec RouteurA ip a add dev rA-eth1 172.16.1.254/24
ip netns exec RouteurA sysctl -w net.ipv4.ip_forward=1
# Route statique pour joindre l'autre côté d'Internet
ip netns exec RouteurA ip r add 172.16.2.0/24 via 10.87.0.2

# RouteurB
ip link add rB-eth0 type veth peer name net-rB
ip link add rB-eth1 type veth peer name resB-rB
ip link set rB-eth0 netns RouteurB
ip link set rB-eth1 netns RouteurB
ovs-vsctl add-port Internet net-rB
ovs-vsctl add-port resB resB-rB
ip link set dev net-rB up
ip link set dev resB-rB up

ip netns exec RouteurB ip link set dev lo up
ip netns exec RouteurB ip link set dev rB-eth0 up
ip netns exec RouteurB ip link set dev rB-eth1 up
ip netns exec RouteurB ip a add dev rB-eth0 10.87.0.2/24
ip netns exec RouteurB ip a add dev rB-eth1 172.16.2.254/24
ip netns exec RouteurB sysctl -w net.ipv4.ip_forward=1
# Route statique pour joindre l'autre côté d'Internet
ip netns exec RouteurB ip r add 172.16.1.0/24 via 10.87.0.1

# ==========================================
# CONFIGURATION DU SITE 1 (Gauche)
# ==========================================

# Routeur1
ip link add r1-eth0 type veth peer name resC-r1
ip link add r1-eth1 type veth peer name resD-r1
ip link set r1-eth0 netns Routeur1
ip link set r1-eth1 netns Routeur1
ovs-vsctl add-port resC resC-r1
ovs-vsctl add-port resD resD-r1
ip link set dev resC-r1 up
ip link set dev resD-r1 up

ip netns exec Routeur1 ip link set dev lo up
ip netns exec Routeur1 ip link set dev r1-eth0 up
ip netns exec Routeur1 ip link set dev r1-eth1 up
ip netns exec Routeur1 ip a add dev r1-eth0 172.16.1.253/24

# Création des interfaces VLANs sur Routeur1
ip netns exec Routeur1 ip link add link r1-eth1 name r1-eth1.100 type vlan id 100
ip netns exec Routeur1 ip link add link r1-eth1 name r1-eth1.200 type vlan id 200
ip netns exec Routeur1 ip link set dev r1-eth1.100 up
ip netns exec Routeur1 ip link set dev r1-eth1.200 up
ip netns exec Routeur1 ip a add dev r1-eth1.100 192.168.100.254/24
ip netns exec Routeur1 ip a add dev r1-eth1.200 192.168.200.254/24
ip netns exec Routeur1 sysctl -w net.ipv4.ip_forward=1
ip netns exec Routeur1 ip r add default via 172.16.1.254

# Poste3 (VLAN 100)
ip link add p3-eth0 type veth peer name resD-p3
ip link set p3-eth0 netns Poste3
ovs-vsctl add-port resD resD-p3
ip link set dev resD-p3 up

ip netns exec Poste3 ip link set dev lo up
ip netns exec Poste3 ip link set dev p3-eth0 up
ip netns exec Poste3 ip link add link p3-eth0 name p3-eth0.100 type vlan id 100
ip netns exec Poste3 ip link set dev p3-eth0.100 up
ip netns exec Poste3 ip a add dev p3-eth0.100 192.168.100.2/24
ip netns exec Poste3 ip r add default via 192.168.100.254

# Poste4 (VLAN 200)
ip link add p4-eth0 type veth peer name resD-p4
ip link set p4-eth0 netns Poste4
ovs-vsctl add-port resD resD-p4
ip link set dev resD-p4 up

ip netns exec Poste4 ip link set dev lo up
ip netns exec Poste4 ip link set dev p4-eth0 up
ip netns exec Poste4 ip link add link p4-eth0 name p4-eth0.200 type vlan id 200
ip netns exec Poste4 ip link set dev p4-eth0.200 up
ip netns exec Poste4 ip a add dev p4-eth0.200 192.168.200.2/24
ip netns exec Poste4 ip r add default via 192.168.200.254

# ==========================================
# CONFIGURATION DU SITE 2 (Droite)
# ==========================================

# Routeur2
ip link add r2-eth0 type veth peer name resB-r2
ip link add r2-eth1 type veth peer name resE-r2
ip link set r2-eth0 netns Routeur2
ip link set r2-eth1 netns Routeur2
ovs-vsctl add-port resB resB-r2
ovs-vsctl add-port resE resE-r2
ip link set dev resB-r2 up
ip link set dev resE-r2 up

ip netns exec Routeur2 ip link set dev lo up
ip netns exec Routeur2 ip link set dev r2-eth0 up
ip netns exec Routeur2 ip link set dev r2-eth1 up
ip netns exec Routeur2 ip a add dev r2-eth0 172.16.2.253/24

# Création des interfaces VLANs sur Routeur2
ip netns exec Routeur2 ip link add link r2-eth1 name r2-eth1.100 type vlan id 100
ip netns exec Routeur2 ip link add link r2-eth1 name r2-eth1.200 type vlan id 200
ip netns exec Routeur2 ip link set dev r2-eth1.100 up
ip netns exec Routeur2 ip link set dev r2-eth1.200 up
ip netns exec Routeur2 ip a add dev r2-eth1.100 192.168.100.253/24
ip netns exec Routeur2 ip a add dev r2-eth1.200 192.168.200.253/24
ip netns exec Routeur2 sysctl -w net.ipv4.ip_forward=1
ip netns exec Routeur2 ip r add default via 172.16.2.254

# Poste1 (VLAN 100)
ip link add p1-eth0 type veth peer name resE-p1
ip link set p1-eth0 netns Poste1
ovs-vsctl add-port resE resE-p1
ip link set dev resE-p1 up

ip netns exec Poste1 ip link set dev lo up
ip netns exec Poste1 ip link set dev p1-eth0 up
ip netns exec Poste1 ip link add link p1-eth0 name p1-eth0.100 type vlan id 100
ip netns exec Poste1 ip link set dev p1-eth0.100 up
ip netns exec Poste1 ip a add dev p1-eth0.100 192.168.100.1/24
ip netns exec Poste1 ip r add default via 192.168.100.253

# Poste2 (VLAN 200)
ip link add p2-eth0 type veth peer name resE-p2
ip link set p2-eth0 netns Poste2
ovs-vsctl add-port resE resE-p2
ip link set dev resE-p2 up

ip netns exec Poste2 ip link set dev lo up
ip netns exec Poste2 ip link set dev p2-eth0 up
ip netns exec Poste2 ip link add link p2-eth0 name p2-eth0.200 type vlan id 200
ip netns exec Poste2 ip link set dev p2-eth0.200 up
ip netns exec Poste2 ip a add dev p2-eth0.200 192.168.200.1/24
ip netns exec Poste2 ip r add default via 192.168.200.253

echo "Le laboratoire de la Question 1 est déployé !"