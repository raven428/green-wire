#!/usr/bin/env bash
[[ -z "${PROTO_DNS}" || -z "${IPREMOTE}" ]] && {
  echo 'var PROTO_DNS or IPREMOTE isn'\''t in env' |
    /usr/bin/env logger -t 'pppup-r2d'
}
# shellcheck disable=1091
source /etc/ppp/ip.d/10-route2dns.sh
tmp_dnsmasq_conf='/var/tmp/dnsmasq-prskt.conf'
# shellcheck disable=2154
/usr/bin/env touch "${prskt_dnsmasq_conf}"
/usr/bin/truncate -s 0 "${tmp_dnsmasq_conf}"
for dns in ${PROTO_DNS}; do
  /sbin/ip ro add "${dns}/32" via "${IPREMOTE}" 2>&1 |
    /usr/bin/env logger -t 'pppup-r2d'
  echo "add [${dns}] via [${IPREMOTE}] route" |
    /usr/bin/env logger -t 'pppup-r2d'
  echo "server=/perspekt.local/${dns}" >>${tmp_dnsmasq_conf}
done
/usr/bin/env diff -u "${tmp_dnsmasq_conf}" "${prskt_dnsmasq_conf}" || {
  /usr/bin/env cp -v "${tmp_dnsmasq_conf}" "${prskt_dnsmasq_conf}"
  /etc/init.d/dnsmasq restart
}
