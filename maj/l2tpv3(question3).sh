#!/bin/bash -x

echo "=== MISE EN PLACE DU TUNNEL L2TPv3 (QUESTION 3) ==="

# ==========================================
# CONFIGURATION DE ROUTEUR 1
# ==========================================

# 1. Nettoyage des anciennes interfaces VLAN
ip netns exec Routeur1 ip link del r1-eth1.100
ip netns exec Routeur1 ip link del r1-eth1.200

# 2. Création du Tunnel L2TPv3 (Encapsulation IP)
ip netns exec Routeur1 ip l2tp add tunnel remote 172.16.2.253 local 172.16.1.253 encap ip tunnel_id 3000 peer_tunnel_id 4000
ip netns exec Routeur1 ip l2tp add session tunnel_id 3000 session_id 1000 peer_session_id 2000
ip netns exec Routeur1 ip link set l2tpeth0 up

# 3. Création du Bridge (Pont) et attachement des interfaces
ip netns exec Routeur1 ip link add pont type bridge
ip netns exec Routeur1 ip link set l2tpeth0 master pont
ip netns exec Routeur1 ip link set r1-eth1 master pont
ip netns exec Routeur1 ip link set pont up

# 4. Recréation des interfaces VLAN attachées au pont
ip netns exec Routeur1 ip link add link pont name pont.100 type vlan id 100
ip netns exec Routeur1 ip link add link pont name pont.200 type vlan id 200
ip netns exec Routeur1 ip link set pont.100 up
ip netns exec Routeur1 ip link set pont.200 up

# 5. Réattribution des adresses IP (Passerelles des réseaux)
ip netns exec Routeur1 ip a add 192.168.100.254/24 dev pont.100
ip netns exec Routeur1 ip a add 192.168.200.254/24 dev pont.200


# ==========================================
# CONFIGURATION DE ROUTEUR 2
# ==========================================

# 1. Nettoyage des anciennes interfaces VLAN
ip netns exec Routeur2 ip link del r2-eth1.100
ip netns exec Routeur2 ip link del r2-eth1.200

# 2. Création du Tunnel L2TPv3 (Encapsulation IP - IDs inversés)
ip netns exec Routeur2 ip l2tp add tunnel remote 172.16.1.253 local 172.16.2.253 encap ip tunnel_id 4000 peer_tunnel_id 3000
ip netns exec Routeur2 ip l2tp add session tunnel_id 4000 session_id 2000 peer_session_id 1000
ip netns exec Routeur2 ip link set l2tpeth0 up

# 3. Création du Bridge (Pont) et attachement des interfaces
ip netns exec Routeur2 ip link add pont type bridge
ip netns exec Routeur2 ip link set l2tpeth0 master pont
ip netns exec Routeur2 ip link set r2-eth1 master pont
ip netns exec Routeur2 ip link set pont up

# 4. Recréation des interfaces VLAN attachées au pont
ip netns exec Routeur2 ip link add link pont name pont.100 type vlan id 100
ip netns exec Routeur2 ip link add link pont name pont.200 type vlan id 200
ip netns exec Routeur2 ip link set pont.100 up
ip netns exec Routeur2 ip link set pont.200 up

# 5. Réattribution des adresses IP (Passerelles des réseaux)
ip netns exec Routeur2 ip a add 192.168.100.253/24 dev pont.100
ip netns exec Routeur2 ip a add 192.168.200.253/24 dev pont.200


# ==========================================
# PRÉPARATION DU TEST DHCP (POSTE 1)
# ==========================================

# On supprime l'IP statique de Poste1 pour l'obliger à demander une IP via DHCP
ip netns exec Poste1 ip a flush dev p1-eth0.100
ip netns exec Poste1 ip a add 192.168.100.1/24 dev p1-eth0.100

echo "=== L'infrastructure de la Question 3 est prête ! ==="