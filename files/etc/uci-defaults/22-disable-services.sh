#!/usr/bin/env bash
set -ueo pipefail
for svc in dockerd podman bird monit softflowd nfcapd tun2ray nginx authelia swanctl; do
  /etc/init.d/${svc} disable
  /etc/init.d/${svc} stop
done

# shellcheck disable=1091
source /lib/functions.sh
case "$(board_name)" in
bananapi,bpi-r3)
  # set default boot to eMMC – twice to affect main and backup config
  # avoid recovery boot with /sys/fs/pstore/* files after kernel panic
  /usr/bin/env fw_setenv bootmenu_default 2
  /usr/bin/env fw_setenv bootmenu_default 2
  ;;
esac
