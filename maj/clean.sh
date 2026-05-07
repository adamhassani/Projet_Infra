#!/bin/bash -x

# Destruction des namespaces
ip netns del RouteurA
ip netns del RouteurB
ip netns del Routeur1
ip netns del Routeur2
ip netns del Poste1
ip netns del Poste2
ip netns del Poste3
ip netns del Poste4

# Destruction des switches OVS
ovs-vsctl del-br Internet
ovs-vsctl del-br resC
ovs-vsctl del-br resB
ovs-vsctl del-br resD
ovs-vsctl del-br resE

echo "L'environnement a été nettoyé avec succès !"