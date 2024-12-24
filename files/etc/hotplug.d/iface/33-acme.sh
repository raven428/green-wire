#!/usr/bin/env bash
[[ "${ACTION}" == "ifup" && "${DEVICE}" == "br-wan" ]] || exit 0
/etc/init.d/acme start 2>&1 |
  /usr/bin/env logger -t "acme-startup"
# /usr/bin/env ip route add ::/0 dev br-wan 2>&1 |
#   /usr/bin/env logger -t "route-wan"
