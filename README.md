# Projet Infra — L2TPv3 / IPsec / VLAN

Simulation réseau complète sous Linux avec namespaces, Open vSwitch et tunnels L2TPv3.

## Architecture

```
[PC1]--+            +--[PC3]
[PC2]--+--[OVS1]--[R1]--R_A--R_B--[R2]--[OVS2]--+--[PC4]
```

- OVS1 / OVS2 : switchs LAN avec VLANs 100 et 200
- R1 / R2 : routeurs Linux (bridge + tunnel)
- R_A / R_B : routeurs WAN intermédiaires
- VLAN 100 : 192.168.100.0/24, VLAN 200 : 192.168.200.0/24

## Scripts

| Script | Rôle |
|--------|------|
| `phase1.sh` | Topologie de base (namespaces, OVS, VLANs, WAN) |
| `phase2.sh` | Bridge Linux + tunnel L2TPv3 (encap IP) |
| `phase3_switch.sh` | Bascule du tunnel : `ip` / `udp` / `gretap` |
| `phase4_dhcp.sh` | DHCP via dnsmasq sur R1 pour les 4 PCs |
| `phase5_ipsec.sh` | IPsec sur le tunnel (AES-128 + SHA1, mode transport) |
| `phase6_internet.sh` | Accès internet + dnsmasq mac-tag PC3/PC4 via R2 |
| `phase7_isolation.sh` | Isolation VLAN 100 <-> 200 via iptables |

## Lancement

```bash
sudo bash phase1.sh
sudo bash phase2.sh
sudo bash phase3_switch.sh ip    # ou udp / gretap
sudo bash phase4_dhcp.sh
sudo bash phase5_ipsec.sh
sudo bash phase6_internet.sh
sudo bash phase7_isolation.sh
```

Chaque script peut être relancé indépendamment (sauf phase1 qui recrée tout).
