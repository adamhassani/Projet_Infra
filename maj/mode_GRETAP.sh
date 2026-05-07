#!/bin/bash -x

# 1 tunnel l2tpv3 off
sudo ip netns exec Routeur1 ip link set l2tpeth0 down

# 2 creeer tunnels
sudo ip netns exec Routeur1 ip link add gretap0 type gretap remote 172.16.2.253 local 172.16.1.253 nopmtudisc

# 3 vlans
sudo ip netns exec Routeur1 ip link set dev gretap0 up
sudo ip netns exec Routeur1 ip link set gretap0 master pont

# mtu
sudo ip netns exec Routeur1 ip link show gretap0



# De meme pour le routeur 2
sudo ip netns exec Routeur2 ip link set l2tpeth0 down
sudo ip netns exec Routeur2 ip link add gretap0 type gretap remote 172.16.1.253 local 172.16.2.253 nopmtudisc
sudo ip netns exec Routeur2 ip link set dev gretap0 up
sudo ip netns exec Routeur2 ip link set gretap0 master pont
sudo ip netns exec Routeur2 ip link show gretap0