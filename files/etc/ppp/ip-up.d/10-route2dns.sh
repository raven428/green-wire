#!/usr/bin/env bash
[[ -z "${PROTO_DNS}" || -z "${IPREMOTE}" ]] && {
  echo 'var PROTO_DNS or IPREMOTE isn'\''t in env' |
    /usr/bin/env logger -t 'pppup-r2d'
}
source /etc/ppp/ip.d/10-route2dns.sh
for dns in ${PROTO_DNS}; do
  /sbin/ip ro add "${dns}/32" via "${IPREMOTE}" 2>&1 |
    /usr/bin/env logger -t 'pppup-r2d'
  echo "add [${dns}] via [${IPREMOTE}] route" |
    /usr/bin/env logger -t 'pppup-r2d'
  echo "server=/perspekt.local/${dns}" >>${prskt_dnsmasq_conf}
done
/etc/init.d/dnsmasq restart
