printf "cert [%s] done [%s] at [%s] dt" "${domains}" "${ACTION}" \
  "$(date '+%Y%m%dT%H%M%S')" |
  /usr/bin/env mutt \
    -e 'set envelope_from=yes' \
    -e "set from=acme@${HOSTNAME}.localdomain" \
    -e 'set realname="служба роботов"' \
    -e 'set send_charset=utf-8' \
    -s 'новости cert подсистемы' \
    "${account_email}"
if [[ "$ACTION" = "renewed" ]]; then
  /etc/init.d/3x-ui status && /etc/init.d/3x-ui restart
fi
