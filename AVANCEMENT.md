# Avancement projet

## Ce qui tourne

| Script | Ce que ca fait | Status |
|--------|---------------|--------|
| phase1.sh | namespaces, OVS, VLANs 100/200, WAN R1-RA-RB-R2 | OK |
| phase2.sh | bridge linux (vlan_filtering), tunnel L2TPv3 IP, gateway IPs sur R1 | OK |
| phase3_switch.sh | bascule tunnel : ip / udp / gretap | OK |
| phase4_dhcp.sh | dnsmasq sur R1, DHCP pour les 4 PCs des deux sites | OK |
| phase5_ipsec.sh | IPsec xfrm (AES+SHA1), iperf comparaison avec/sans | OK |
| phase6_internet.sh | NAT host+R1, accès internet, dnsmasq mac-tag PC3/PC4 -> R2 | OK |
| phase7_isolation.sh | DROP iptables cross-VLAN sur R1 et R2 | OK |

Tests validés :
- ping PC1 <-> PC3 (VLAN 100, tunnel) : OK
- ping PC2 <-> PC4 (VLAN 200, tunnel) : OK
- ping PC1 -> PC2 (cross-VLAN) : BLOQUE (isolation OK)
- PC3/PC4 recoivent leur IP depuis dnsmasq sur R1 via tunnel : OK
- PC1 -> 8.8.8.8 via R1 : OK
- PC3 -> 8.8.8.8 via R2 (dnsmasq mac-tag) : OK
- IPsec : iperf 861 Mbits/s sans, 850 Mbits/s avec (~1.3% overhead)
- switch ip/udp/gretap sans reconfigurer le bridge : OK

## Il reste

- [ ] relire et nettoyer les scripts avant rendu
- [ ] faire les captures tcpdump pour le rapport (voir section ci-dessous)
- [ ] section écrite tâche 2 (L2TPv3 vs VXLAN vs MPLS)

---

## A mettre dans le rapport (captures à faire)

### Tâche 1 — VLANs OVS
- capture tcpdump d'une trame VLAN taguée entre un PC et son routeur
  - `tcpdump -i veth-ovs1-pc1 -e -n vlan` pendant un ping PC1 -> R1
  - commenter : tag VLAN 100, adresses MAC source/destination, sens

### Tâche 2 — section écrite (pas de script)
- L2TPv3 (RFC 3931) : encapsulation, sessions/tunnels, proto 115 ou UDP
- VXLAN (RFC 7348) : encapsulation UDP, VNI 24 bits, flood+learn ou controle-plane
- comparaison L2TPv3 vs VXLAN : overhead, chiffrement natif, cas d'usage datacenter vs WAN
- MPLS : label switching (niveau 2.5), pas un tunnel L2, différences fondamentales
- chiffrement : L2TPv3 via IPsec (notre cas), VXLAN via IPsec ou WireGuard

### Tâche 3 — L2TPv3 en action
- capture ARP pendant ping PC1 -> PC3 pour montrer que l'ARP traverse le tunnel
  - `ip netns exec R1 tcpdump -i eth0 -n proto 115` pendant le ping
- capture DHCP PC3 qui arrive sur R1 via le tunnel
  - `ip netns exec R1 tcpdump -i br0.100 -n port 67 or port 68`
- test socat TCP à travers le tunnel :
  - R1 : `ip netns exec R1 socat TCP-LISTEN:1234,fork -`
  - PC3 : `ip netns exec PC3 socat - TCP:192.168.100.254:1234`

### Tâche 4 — Comparaison modes tunnel
- mode IP (proto 115)  : `ip netns exec R1 tcpdump -i eth0 -n -vv proto 115`
- mode UDP             : `ip netns exec R1 tcpdump -i eth0 -n -vv udp port 5000`
- mode GRETAP          : `ip netns exec R1 tcpdump -i eth0 -n -vv proto gre`
- analyser : headers IP extern, header L2TP/GRE, frame Ethernet interne, overhead

### Tâche 5 — IPsec
- montrer `ip netns exec R1 ip xfrm state` et `ip xfrm policy` (policies proto 115)
- capture avant : `ip netns exec R1 tcpdump -i eth0 -n proto 115 -w /tmp/avant.pcap`
- capture apres : meme commande, le contenu doit etre ESP (chiffré)
- tableau iperf : sans IPsec 861 Mbits/s, avec IPsec 850 Mbits/s

### Tâche 6 — Accès Internet
- `ip netns exec R1 iptables -t nat -L -n` pour montrer les regles MASQUERADE
- traceroute ou tcpdump sur host-internet pour montrer que PC1 sort par R1
  - `tcpdump -i host-internet -n` pendant `ip netns exec PC1 ping 8.8.8.8`
- `ip netns exec PC3 ip route` pour montrer GW=192.168.100.253 (R2)
- `ip netns exec PC4 ip route` pour montrer GW=192.168.200.253 (R2)

### Tâche 7 — Isolation VLAN
- `ip netns exec R1 iptables -L FORWARD -n` pour montrer les regles DROP
- ping PC1 -> PC2 : ECHEC attendu (cross-VLAN bloque)
- ping PC1 -> PC3 : OK (meme VLAN, juste bridgé au L2 dans le tunnel)
