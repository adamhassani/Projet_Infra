#!/bin/bash -x



## Creation des namespaces

ip netns add routeurA
ip netns add routeurB
ip netns add routeur1
ip netns add routeur2

ip netns add poste1
ip netns add poste2
ip netns add poste3
ip netns add poste4


## Creation des veths

ip link add veth-routeurA-routeur1 type veth peer name veth-routeur1-routeurA



ip link add veth-routeurB-routeur2 type veth peer name veth-routeur2-routeurB

ip link add veth-routeur1-poste3 type veth peer name veth-poste3-routeur1
ip link add veth-routeur1-poste4 type veth peer name veth-poste4-routeur1

ip link add veth-routeur2-poste1 type veth peer name veth-poste1-routeur2
ip link add veth-routeur2-poste2 type veth peer name veth-poste2-routeur2


## Assignation des interfaces dans les namespaces

ip link set veth-routeurA-routeur1 netns routeurA
ip link set veth-routeur1-routeurA netns routeur1

ip link set veth-routeurB-routeur2 netns routeurB
ip link set veth-routeur2-routeurB netns routeur2

ip link set veth-routeur1-poste3 netns routeur1
ip link set veth-poste3-routeur1 netns poste3

ip link set veth-routeur1-poste4 netns routeur1
ip link set veth-poste4-routeur1 netns poste4

ip link set veth-routeur2-poste1 netns routeur2
ip link set veth-poste1-routeur2 netns poste1

ip link set veth-routeur2-poste2 netns routeur2
ip link set veth-poste2-routeur2 netns poste2


## Activation des interfaces

ip netns exec routeurA ip link set lo up
ip netns exec routeurB ip link set lo up
ip netns exec routeur1 ip link set lo up
ip netns exec routeur2 ip link set lo up

ip netns exec poste1 ip link set lo up
ip netns exec poste2 ip link set lo up
ip netns exec poste3 ip link set lo up
ip netns exec poste4 ip link set lo up


## Activation des interfaces veth

ip netns exec routeurA ip link set veth-routeurA-routeur1 up
ip netns exec routeur1 ip link set veth-routeur1-routeurA up

ip netns exec routeurA ip link set veth-routeurA-routeurB up
ip netns exec routeurB ip link set veth-routeurB-routeurA up

ip netns exec routeurB ip link set veth-routeurB-routeur2 up
ip netns exec routeur2 ip link set veth-routeur2-routeurB up

ip netns exec routeur1 ip link set veth-routeur1-poste3 up
ip netns exec poste3 ip link set veth-poste3-routeur1 up

ip netns exec routeur1 ip link set veth-routeur1-poste4 up
ip netns exec poste4 ip link set veth-poste4-routeur1 up

ip netns exec routeur2 ip link set veth-routeur2-poste1 up
ip netns exec poste1 ip link set veth-poste1-routeur2 up

ip netns exec routeur2 ip link set veth-routeur2-poste2 up
ip netns exec poste2 ip link set veth-poste2-routeur2 up


## Attribution des adresses IP

ip netns exec routeurA ip addr add 172.16.1.254/24 dev veth-routeurA-routeur1
ip netns exec routeur1 ip addr add 172.16.1.253/24 dev veth-routeur1-routeurA

ip netns exec routeurB ip addr add 172.16.2.254/24 dev veth-routeurB-routeur2
ip netns exec routeur2 ip addr add 172.16.2.253/24 dev veth-routeur2-routeurB


