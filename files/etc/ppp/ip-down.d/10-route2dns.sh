#!/usr/bin/env bash
# shellcheck disable=1091
source /etc/ppp/ip.d/10-route2dns.sh
# shellcheck disable=2154
/usr/sbin/nft "flush set inet fw4 ${prskt_nftset}" 2>&1 |
  /usr/bin/env logger -t 'pppdown-r2d'
echo "flush [${prskt_nftset}] nftset" |
  /usr/bin/env logger -t 'pppup-r2d'
