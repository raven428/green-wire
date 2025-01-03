#!/usr/bin/env bash
set -ueo pipefail
: "${WRT_OPKG_REPO:="downloads.openwrt.org"}"
/usr/bin/env cp -r files prepare
/usr/bin/env cat <<EOF >prepare/etc/secrets.sh
export WRT_ROOT_PASSWD='${WRT_DEF_PASSWD:-"luc1-r00t+pa5Swd"}'
export WRT_LUCI_CGI='${WRT_LUCI_CGI:-"cgi-bin"}'
export WRT_LUCI_STA='${WRT_LUCI_STA:-"luci-static"}'
export WRT_CLOFA_TO='${WRT_CLOFA_TO:-"cloudflare-token-for-ddns"}'
export WRT_CLOFA_ZO='${WRT_CLOFA_ZO:-"cloudflare-zone-for-ddns"}'
export WRT_SMTP_HOST='${WRT_SMTP_HOST:-"smtp-relay-host"}'
export WRT_SMTP_LOGIN='${WRT_SMTP_LOGIN:-"smtp-relay-login"}'
export WRT_SMTP_PASSWD='${WRT_SMTP_PASSWD:-"smtp-relay-password"}'
export WRT_HOSTNAME='${WRT_HOSTNAME:-"werter"}'
export WRT_SECRET_TLD='${WRT_SECRET_TLD:-"domain.tld"}'
export WRT_OPKG_REPO='${WRT_OPKG_REPO}'
export WRT_LAN3OCT='${WRT_LAN3OCT:-"192.168.69"}'
export WRT_WIFI_SSID='${WRT_WIFI_SSID:-"werter"}'
export WRT_WIFI_KEY='${WRT_WIFI_KEY:-"d3fAu1t!w1F1-ke4"}'
export WRT_CLIENTS='${WRT_CLIENTS:-"caga@50:e5:49:cb:b5:67#1
dir300@00:21:91:31:98:60#99"}'
EOF
for f in prepare/etc/dnsmasq.d/*.sets; do
  r="${f##*/}"
  r="${r%.*}"
  sed -E "/^[[:space:]]*#/b ; /^[[:space:]]*$/b ;
    s~^(.*)$~nftset=/\1/4#inet#fw4#vpn4_${r},6#inet#fw4#vpn6_${r}~
  " -i "${f}"
done
/usr/bin/env mkdir -vp prepare/etc/opkg
/usr/bin/env cat <<EOF >prepare/etc/opkg/distfeeds.conf
src/gz openwrt_core      https://${WRT_OPKG_REPO}/releases/23.05.5/targets/mediatek/filogic/packages
src/gz openwrt_base      https://${WRT_OPKG_REPO}/releases/23.05.5/packages/aarch64_cortex-a53/base
src/gz openwrt_luci      https://${WRT_OPKG_REPO}/releases/23.05.5/packages/aarch64_cortex-a53/luci
src/gz openwrt_routing   https://${WRT_OPKG_REPO}/releases/23.05.5/packages/aarch64_cortex-a53/routing
src/gz openwrt_packages  https://${WRT_OPKG_REPO}/releases/23.05.5/packages/aarch64_cortex-a53/packages
src/gz openwrt_telephony https://${WRT_OPKG_REPO}/releases/23.05.5/packages/aarch64_cortex-a53/telephony
EOF
/usr/bin/env docker run --user 0 --rm -i --network=host \
  -v "$(pwd)"/prepare:/files:rw \
  -v "$(pwd)"/release:/builder/bin/targets/mediatek/filogic:rw \
  ghcr.io/raven428/container-images/openwrt-imagebuilder/mediatek-filogic-23_05_5 \
  /usr/bin/env bash -c '
  cp -v /files/etc/opkg/distfeeds.conf /builder/repositories.conf &&
  make image PROFILE='\''bananapi_bpi-r3'\'' FILES=/files ROOTFS_PARTSIZE=1111 EXTRA_PARTSIZE=6111 PACKAGES='\''-dnsmasq lsblk mmc-utils ca-certificates coreutils coreutils-mktemp coreutils-env coreutils-dd coreutils-cp coreutils-rm coreutils-mv coreutils-sort coreutils-rmdir coreutils-mkdir coreutils-ln coreutils-chown bsdtar coreutils-chmod coreutils-touch coreutils-echo coreutils-timeout curl ethtool iperf iperf3 tar nand-utils python3 pv tmux tcpdump terminfo fdisk sfdisk cfdisk gdisk cgdisk xzdiff parted openssh-sftp-server luci bash vim-fuller libgcc conntrack libustream-mbedtls nftables losetup resize2fs dnsmasq-full less shadow-chsh git fping ddns-scripts-cloudflare fail2ban bird2 bird2c bird2cl netcat luci-proto-wireguard diffutils wireguard-tools wg-installer-client atop btop ctop htop iftop ss jq yq rsync hping3 socksify luci-mod-dashboard luci-app-ddns mutt blkid strace dockerd docker-compose prometheus-node-exporter-lua shadow-usermod bsdiff bspatch dnscrypt-proxy2 prometheus-node-exporter-lua-nat_traffic stubby kmod-nft-tproxy prometheus-node-exporter-lua-netstat prometheus-node-exporter-lua-openwrt docker prometheus-node-exporter-lua-thermal prometheus-node-exporter-lua-wifi prometheus-node-exporter-lua-wifi_stations grep xzgrep block-mount zram-swap file procps-ng-free procps-ng-pgrep procps-ng-pkill procps-ng-pmap procps-ng-pwdx procps-ng-skill procps-ng-slabtop lm-sensors logger patch procps-ng-snice procps-ng-sysctl procps-ng-vmstat procps-ng-w procps-ng-watch procps-ng-top procps-ng-snice procps-ng-kill procps-ng-ps procps-ng-uptime monit xzless xzgrep ack grep zoneinfo-all openssl-util msmtp bind-dig bind-host bind-nslookup whereis iputils-ping iputils-arping iputils-clockdiff iputils-tracepath mtr-json clocate acme-acmesh-dnsapi luci-app-acme iputils-clockdiff nfdump softflowd flock msmtp-queue shadow-passwd shadow-chpasswd podman whois findutils-find findutils-xargs findutils-locate jool-tools-netfilter kmod-tun telnet-bsd'\'''
/usr/bin/env sudo chown -R "${USER}" release
