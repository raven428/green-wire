#!/usr/bin/env bash
set -ueo pipefail
for svc in dockerd podman bird monit softflowd nfcapd; do
  /etc/init.d/${svc} disable
  /etc/init.d/${svc} stop
done
