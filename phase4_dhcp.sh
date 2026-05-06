#!/bin/bash
set -e

# serveur DHCP sur R1 uniquement, un dnsmasq par vlan
# les PCs des deux sites reccoivent leur IP depuis R1 (meme ceux derriere R2 via le tunnel)

echo "=== Phase 4 : DHCP sur R1 ==="

# arret des anciens dnsmasq
[ -f /tmp/dnsmasq-vlan100.pid ] && kill "$(cat /tmp/dnsmasq-vlan100.pid)" 2>/dev/null || true
[ -f /tmp/dnsmasq-vlan200.pid ] && kill "$(cat /tmp/dnsmasq-vlan200.pid)" 2>/dev/null || true
rm -f /tmp/dnsmasq-vlan*.leases /tmp/dnsmasq-vlan*.pid

# flush les IPs statiques des PCs avant de tester le DHCP
for ns in PC1 PC2 PC3 PC4; do
    ip netns exec $ns ip addr flush dev eth0 2>/dev/null || true
done

# dnsmasq vlan 100 sur br0.100
ip netns exec R1 dnsmasq \
    --interface=br0.100 \
    --bind-interfaces \
    --port=0 \
    --dhcp-range=192.168.100.100,192.168.100.200,255.255.255.0,1h \
    --dhcp-option=option:router,192.168.100.254 \
    --dhcp-option=option:dns-server,1.1.1.1 \
    --no-resolv \
    --dhcp-leasefile=/tmp/dnsmasq-vlan100.leases \
    --pid-file=/tmp/dnsmasq-vlan100.pid

# dnsmasq vlan 200 sur br0.200
ip netns exec R1 dnsmasq \
    --interface=br0.200 \
    --bind-interfaces \
    --port=0 \
    --dhcp-range=192.168.200.100,192.168.200.200,255.255.255.0,1h \
    --dhcp-option=option:router,192.168.200.254 \
    --dhcp-option=option:dns-server,1.1.1.1 \
    --no-resolv \
    --dhcp-leasefile=/tmp/dnsmasq-vlan200.leases \
    --pid-file=/tmp/dnsmasq-vlan200.pid

# demandes DHCP depuis les 4 postes
for ns in PC1 PC2 PC3 PC4; do
    ip netns exec $ns dhclient -1 eth0
done

echo ""
echo "IPs obtenues :"
for ns in PC1 PC2 PC3 PC4; do
    IP=$(ip netns exec $ns ip -4 addr show eth0 | grep inet | awk '{print $2}')
    GW=$(ip netns exec $ns ip route show default | awk '{print $3}')
    echo "  $ns : $IP  gw=$GW"
done

echo ""
echo "Baux accordes par R1 :"
cat /tmp/dnsmasq-vlan100.leases 2>/dev/null
cat /tmp/dnsmasq-vlan200.leases 2>/dev/null

echo "=== Phase 4 OK ==="
