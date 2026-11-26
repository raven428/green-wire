#!/bin/sh
[ "${INSTANCE}" = 'ovepn' ] || exit 0
/usr/bin/env printenv | /usr/bin/env logger -t "ovepn-env-${ACTION}"
