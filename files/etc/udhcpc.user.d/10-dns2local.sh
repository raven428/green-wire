#!/usr/bin/env bash
# cspell:ignore adxhks asehdb aswg boosty chizhik clstorage donationalerts kinopoisk
# cspell:ignore memealerts mradx mycdn naydex ozonusercontent perekrestok rostaxi userapi
# cspell:ignore vkcache vkgo vklive vkmessenger vkuser vkuseraudio vkuserlive vkuservideo
# cspell:ignore webvisor yads yandexadexchange yandexcom yandexmetrica yandexwebcache
# cspell:ignore yastat yastatic
domestic_domains='xn--p1ai/xn--p1acf/xn--c1avg/xn--80aswg/xn--d1acj3b/xn--80asehdb
/xn--80adxhks/ru/su/yandex/moscow/ru.com/ru.net/boosty.to/donationalerts.com
/memealerts.com/mycdn.me/ozonusercontent.com/naydex.net/rostaxi.org/webvisor.com
/webvisor.org/yads.tech/yandex-bank.net/yandex-images.clstorage.net/yandex.aero/yandex.az
/yandex.by/yandex.cloud/yandex.co.il/yandex.com/yandex.com.am/yandex.com.ge/yandex.com.tr
/yandex.com.ua/yandex.de/yandex.ee/yandex.eu/yandex.fi/yandex.fr/yandex.jobs/yandex.kg
/yandex.kz/yandex.lt/yandex.lv/yandex.md/yandex.net/yandex.org/yandex.pl/yandex.st
/yandex.sx/yandex.tj/yandex.tm/yandex.ua/yandex.uz/yandexadexchange.net/yandexcloud.net
/yandexcom.net/yandexmetrica.com/yandexwebcache.org/yastat.net/yastatic.net
/kinopoisk-ru.clstorage.net/5post.market/chizhik.club/perekrestok.com/x5.com/x5.digital
/x5.group/x5.media/x5.team/x5.tech/x5static.net/mradx.net/mvk.com/userapi.com
/vk-apps.com/vk-cdn.me/vk-cdn.net/vk-portal.net/vk.cc/vk.com/vk.company/vk.design
/vk.link/vk.me/vk.team/vkcache.com/vkgo.app/vklive.app/vkmessenger.app/vkmessenger.com
/vkuser.net/vkuseraudio.com/vkuseraudio.net/vkuserlive.net/vkuservideo.com
/vkuservideo.net/cn'
# Yandex and НСДИ
domestic_servers='77.88.8.1 77.88.8.8 195.208.4.1 195.208.5.1'
[[ -z "${PROTO_DNS:-}" ]] &&
  echo 'var PROTO_DNS isn'\''t in env' |
  /usr/bin/env logger -t 'udhcpc'
domestic_dnsmasq_conf='/etc/dnsmasq.d/wan-servers.conf'
tmp_dnsmasq_conf='/var/tmp/wan-servers.conf'
/usr/bin/env touch "${domestic_dnsmasq_conf}"
/usr/bin/truncate -s 0 "${tmp_dnsmasq_conf}"
domains="${domestic_domains//[[:space:]]/}"
for dns in ${PROTO_DNS:-} ${domestic_servers}; do
  domain_chunk='server='
  remaining="${domains}"
  while [[ -n "${remaining}" ]]; do
    domain="${remaining%%/*}"
    case "${remaining}" in
    */*) remaining="${remaining#*/}" ;;
    *) remaining='' ;;
    esac
    if [[ $((${#domain_chunk} + ${#domain} + ${#dns} + 2)) -gt 777 ]]; then
      printf '%s/%s\n' "${domain_chunk}" "${dns}" >>"${tmp_dnsmasq_conf}"
      domain_chunk='server='
    fi
    domain_chunk="${domain_chunk}/${domain}"
  done
  printf '%s/%s\n' "${domain_chunk}" "${dns}" >>"${tmp_dnsmasq_conf}"
done
/usr/bin/env diff -u "${domestic_dnsmasq_conf}" "${tmp_dnsmasq_conf}" || {
  /usr/bin/env cp -v "${tmp_dnsmasq_conf}" "${domestic_dnsmasq_conf}"
  /etc/init.d/dnsmasq restart
}
