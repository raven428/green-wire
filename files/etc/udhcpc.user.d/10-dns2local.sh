#!/usr/bin/env bash
domestic_domains='pjreo74.ru
/farmlend.ru'
# Yandex and НСДИ
domestic_servers='77.88.8.1 77.88.8.9 195.208.4.1 195.208.5.1'
[[ -z "${PROTO_DNS:-}" ]] &&
  echo 'var PROTO_DNS isn'\''t in env' |
  /usr/bin/env logger -t 'udhcpc'
domestic_dnsmasq_conf='/etc/dnsmasq.d/wan-servers.conf'
tmp_dnsmasq_conf='/var/tmp/wan-servers.conf'
/usr/bin/env touch "${domestic_dnsmasq_conf}"
/usr/bin/truncate -s 0 "${tmp_dnsmasq_conf}"
for dns in ${PROTO_DNS:-} ${domestic_servers}; do
  echo "server=/${domestic_domains//[[:space:]]/}/${dns}" >>${tmp_dnsmasq_conf}
done
/usr/bin/env diff -u "${domestic_dnsmasq_conf}" "${tmp_dnsmasq_conf}" || {
  /usr/bin/env cp -v "${tmp_dnsmasq_conf}" "${domestic_dnsmasq_conf}"
  /etc/init.d/dnsmasq restart
}
