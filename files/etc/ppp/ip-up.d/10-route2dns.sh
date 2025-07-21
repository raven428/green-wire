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
# shellcheck disable=2154
/usr/sbin/nft "flush set inet fw4 ${prskt_nftset}"
dns_list=''
for dns in ${PROTO_DNS}; do
  [[ "${dns_list}" != '' ]] && dns_list="${dns_list},"
  dns_list="${dns_list}${dns}"
  echo "server=/perspekt.local/${dns}" >>${tmp_dnsmasq_conf}
done
if [[ "${dns_list}" != '' ]]; then
  /usr/sbin/nft "add element inet fw4 ${prskt_nftset} {${dns_list}}" 2>&1 |
    /usr/bin/env logger -t 'pppup-r2d'
  echo "add [${dns_list}] via [${IPREMOTE}] route" |
    /usr/bin/env logger -t 'pppup-r2d'
else
  echo "no DNS servers via [${IPREMOTE}] route" |
    /usr/bin/env logger -t 'pppup-r2d'
fi
/usr/bin/env diff -u "${tmp_dnsmasq_conf}" "${prskt_dnsmasq_conf}" || {
  /usr/bin/env cp -v "${tmp_dnsmasq_conf}" "${prskt_dnsmasq_conf}"
  /etc/init.d/dnsmasq restart
}
