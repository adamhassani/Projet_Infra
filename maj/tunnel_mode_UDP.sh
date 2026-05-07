#!/bin/bash -x


# 1. On détruit l'ancien tunnel IP
sudo ip netns exec Routeur1 ip l2tp del session tunnel_id 3000 session_id 1000
sudo ip netns exec Routeur1 ip l2tp del tunnel tunnel_id 3000

# 2. On crée le nouveau tunnel en mode UDP (udp_sport et udp_dport)
sudo ip netns exec Routeur1 ip l2tp add tunnel remote 172.16.2.253 local 172.16.1.253 encap udp udp_sport 5000 udp_dport 6000 tunnel_id 3000 peer_tunnel_id 4000
sudo ip netns exec Routeur1 ip l2tp add session tunnel_id 3000 session_id 1000 peer_session_id 2000
sudo ip netns exec Routeur1 ip link set l2tpeth0 up

# 3. On raccroche l'interface au pont
sudo ip netns exec Routeur1 ip link set l2tpeth0 master pont



# La meme chose pour Routeur2
sudo ip netns exec Routeur2 ip l2tp del session tunnel_id 4000 session_id 2000
sudo ip netns exec Routeur2 ip l2tp del tunnel tunnel_id 4000
sudo ip netns exec Routeur2 ip l2tp add tunnel remote 172.16.1.253 local 172.16.2.253 encap udp udp_sport 6000 udp_dport 5000 tunnel_id 4000 peer_tunnel_id 3000
sudo ip netns exec Routeur2 ip l2tp add session tunnel_id 4000 session_id 2000 peer_session_id 1000
sudo ip netns exec Routeur2 ip link set l2tpeth0 up
sudo ip netns exec Routeur2 ip link set l2tpeth0 master pont