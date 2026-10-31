#!/bin/sh
[ "${INSTANCE}" = 'ovepn' ] || exit 0
/usr/libexec/ovepn-hook "${ACTION}" 2>&1 | /usr/bin/env logger -t 'ovepn-hook'
