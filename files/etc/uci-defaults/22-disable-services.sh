#!/usr/bin/env bash
set -ueo pipefail
for svc in dockerd podman bird monit softflowd nfcapd tun2ray; do
  /etc/init.d/${svc} disable
  /etc/init.d/${svc} stop
done
