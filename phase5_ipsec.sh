#!/bin/bash
set -e

# IPsec en mode transport sur le tunnel L2TPv3 (proto 115 = L2TP over IP)
# chiffrement AES-128-CBC + integrité HMAC-SHA1
# les clés sont generees ici et partagées manuellement entre R1 et R2

# option --flush pour desactiver IPsec rapidement (utile pour comparer avec iperf)
if [ "${1}" = "--flush" ]; then
    echo "Suppression IPsec..."
    for ns in R1 R2; do
        ip netns exec $ns ip xfrm state  flush
        ip netns exec $ns ip xfrm policy flush
    done
    echo "IPsec desactive."
    exit 0
fi

echo "=== Phase 5 : IPsec ==="

# nettoyage
for ns in R1 R2; do
    ip netns exec $ns ip xfrm state  flush 2>/dev/null || true
    ip netns exec $ns ip xfrm policy flush 2>/dev/null || true
done

# generation des cles (une seule fois, utilisées des deux cotés)
AES_KEY="0x$(openssl rand -hex 16)"
SHA_KEY="0x$(openssl rand -hex 20)"
SPI_OUT=0x1001
SPI_IN=0x1002

# Security Associations (SA)
# R1 -> R2
ip netns exec R1 ip xfrm state add \
    src 10.0.1.1 dst 10.0.3.2 proto esp spi $SPI_OUT mode transport \
    enc 'cbc(aes)' $AES_KEY auth 'hmac(sha1)' $SHA_KEY

ip netns exec R2 ip xfrm state add \
    src 10.0.1.1 dst 10.0.3.2 proto esp spi $SPI_OUT mode transport \
    enc 'cbc(aes)' $AES_KEY auth 'hmac(sha1)' $SHA_KEY

# R2 -> R1
ip netns exec R2 ip xfrm state add \
    src 10.0.3.2 dst 10.0.1.1 proto esp spi $SPI_IN mode transport \
    enc 'cbc(aes)' $AES_KEY auth 'hmac(sha1)' $SHA_KEY

ip netns exec R1 ip xfrm state add \
    src 10.0.3.2 dst 10.0.1.1 proto esp spi $SPI_IN mode transport \
    enc 'cbc(aes)' $AES_KEY auth 'hmac(sha1)' $SHA_KEY

# Security Policies (SP) - s'appliquent uniquement au proto 115
# R1 : out chiffre, in dechiffre
ip netns exec R1 ip xfrm policy add \
    src 10.0.1.1/32 dst 10.0.3.2/32 proto 115 dir out \
    tmpl src 10.0.1.1 dst 10.0.3.2 proto esp mode transport

ip netns exec R1 ip xfrm policy add \
    src 10.0.3.2/32 dst 10.0.1.1/32 proto 115 dir in \
    tmpl src 10.0.3.2 dst 10.0.1.1 proto esp mode transport

# R2 : pareil mais dans l'autre sens
ip netns exec R2 ip xfrm policy add \
    src 10.0.3.2/32 dst 10.0.1.1/32 proto 115 dir out \
    tmpl src 10.0.3.2 dst 10.0.1.1 proto esp mode transport

ip netns exec R2 ip xfrm policy add \
    src 10.0.1.1/32 dst 10.0.3.2/32 proto 115 dir in \
    tmpl src 10.0.1.1 dst 10.0.3.2 proto esp mode transport

echo ""
echo "SA actives sur R1 :"
ip netns exec R1 ip xfrm state list

echo ""
echo "Policies actives sur R1 :"
ip netns exec R1 ip xfrm policy list

# test de connectivite
echo ""
echo "Test ping PC1 -> PC3 avec IPsec actif..."
ip netns exec PC1 ping -c 3 192.168.100.30

echo ""
echo "Compteurs (bytes chiffrés depuis R1) :"
ip netns exec R1 ip xfrm state list | grep -E "src 10.0.1.1|bytes"

echo "=== Phase 5 OK ==="
echo ""
echo "Pour desactiver IPsec : sudo bash phase5_ipsec.sh --flush"
