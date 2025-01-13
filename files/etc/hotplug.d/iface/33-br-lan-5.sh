#!/usr/bin/env bash
[[ "${ACTION}" == "ifup" && "${DEVICE}" == "br-lan.5" ]] || exit 0
/etc/init.d/acme start 2>&1 |
  /usr/bin/env logger -t 'acme-startup'
/usr/bin/env ip route add ::/0 dev br-lan.5 2>&1 |
  /usr/bin/env logger -t 'route-wan'
/etc/init.d/3x-tpro restart 2>&1 |
  /usr/bin/env logger -t '3x-tpro'
