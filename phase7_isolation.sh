#!/bin/bash
set -e

# isolation inter-vlan : bloquer que le trafic VLAN100 <-> VLAN200 passe par R1 ou R2
# le forwarding IP est actif sur R1 (et R2 apres phase6), donc sans regle iptables
# un PC pourrait router vers l'autre vlan via la gateway

echo "=== Phase 7 : Isolation VLAN ==="

# avant isolation : test pour montrer que ca passe
echo "[*] Avant isolation :"
if ip netns exec PC1 ping -c 1 -W 2 192.168.200.20 >/dev/null 2>&1; then
    echo "  PC1 -> PC2 (cross-vlan) : passe (normal, pas encore bloque)"
else
    echo "  PC1 -> PC2 (cross-vlan) : deja bloque"
fi

# regles DROP sur R1 entre les deux sous-reseaux
echo ""
echo "[*] Ajout regles iptables FORWARD sur R1"
ip netns exec R1 iptables -C FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP 2>/dev/null || \
    ip netns exec R1 iptables -A FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP
ip netns exec R1 iptables -C FORWARD -s 192.168.200.0/24 -d 192.168.100.0/24 -j DROP 2>/dev/null || \
    ip netns exec R1 iptables -A FORWARD -s 192.168.200.0/24 -d 192.168.100.0/24 -j DROP

# meme chose sur R2 (qui a aussi du forwarding apres phase6)
echo "[*] Ajout regles iptables FORWARD sur R2"
ip netns exec R2 iptables -C FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP 2>/dev/null || \
    ip netns exec R2 iptables -A FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP
ip netns exec R2 iptables -C FORWARD -s 192.168.200.0/24 -d 192.168.100.0/24 -j DROP 2>/dev/null || \
    ip netns exec R2 iptables -A FORWARD -s 192.168.200.0/24 -d 192.168.100.0/24 -j DROP

echo ""
echo "[*] Tests apres isolation :"

# cross-vlan : doit etre bloque
if ip netns exec PC1 ping -c 1 -W 2 192.168.200.20 >/dev/null 2>&1; then
    echo "  PC1 -> PC2 (cross-vlan 100->200) : passe -- PROBLEME"
else
    echo "  PC1 -> PC2 (cross-vlan 100->200) : bloque OK"
fi

if ip netns exec PC2 ping -c 1 -W 2 192.168.100.10 >/dev/null 2>&1; then
    echo "  PC2 -> PC1 (cross-vlan 200->100) : passe -- PROBLEME"
else
    echo "  PC2 -> PC1 (cross-vlan 200->100) : bloque OK"
fi

# meme vlan : doit marcher (IPs dynamiques post-DHCP)
IP_PC3=$(ip netns exec PC3 ip addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
IP_PC4=$(ip netns exec PC4 ip addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
echo "  (IPs DHCP : PC3=$IP_PC3, PC4=$IP_PC4)"

if ip netns exec PC1 ping -c 2 -W 2 "$IP_PC3" >/dev/null 2>&1; then
    echo "  PC1 -> PC3 (meme vlan 100, tunnel) : OK"
else
    echo "  PC1 -> PC3 (meme vlan 100, tunnel) : ECHEC"
fi

if ip netns exec PC2 ping -c 2 -W 2 "$IP_PC4" >/dev/null 2>&1; then
    echo "  PC2 -> PC4 (meme vlan 200, tunnel) : OK"
else
    echo "  PC2 -> PC4 (meme vlan 200, tunnel) : ECHEC"
fi

# cross-vlan site 2
if ip netns exec PC3 ping -c 1 -W 2 192.168.200.40 >/dev/null 2>&1; then
    echo "  PC3 -> PC4 (cross-vlan via R2) : passe -- PROBLEME"
else
    echo "  PC3 -> PC4 (cross-vlan via R2)  : bloque OK"
fi

echo ""
echo "=== Phase 7 OK ==="
