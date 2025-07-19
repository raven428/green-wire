#!/usr/bin/env bash
# shellcheck disable=2154
/usr/bin/env printf 'Hello,\n
There are cert action [%s] performed [%s] at [%s] date/time\n
-- \nYour [%s] sincerely. Have a good time!\n' "${domains}" "${ACTION}" \
  "$(/usr/bin/env date '+%Y%m%dT%H%M%S.%3N')" \
  "${HOSTNAME}" |
  /usr/bin/env mutt \
    -e 'set envelope_from=yes' \
    -e "set from=acme@${HOSTNAME}.localdomain" \
    -e 'set realname="служба роботов"' \
    -e 'set send_charset=utf-8' \
    -s 'новости cert подсистемы' \
    "${account_email}"
if [[ "$ACTION" == "issued" || "$ACTION" == "renewed" ]]; then
  domain="${main_domain#"${main_domain%%[![:space:]]*}"}"
  {
    /usr/bin/env ln -sfv "/etc/ssl/acme/${domain}.key" \
      '/etc/ssl/private/main.key'
    /usr/bin/env ln -sfv "/etc/ssl/acme/${domain}.fullchain.crt" \
      '/etc/ssl/private/main.crt'
    /usr/bin/env ln -sfv "/etc/ssl/acme/${domain}.combined.crt" \
      '/etc/ssl/private/main.pem'
    for svc in 3x-ui uhttpd nginx haproxy; do
      /etc/init.d/${svc} status && /etc/init.d/${svc} restart
    done
  } 2>&1 | /usr/bin/env logger -t 'acme-issued'
fi
