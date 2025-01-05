#!/usr/bin/env bash
set -ueo pipefail
: "${WRT_OPKG_REPO:="downloads.openwrt.org"}"
/usr/bin/env cp -r files prepare
/usr/bin/env cat <<EOF >prepare/etc/secrets.sh
export WRT_GREWIBU='${VER:-"999"}'
export WRT_ROOT_PASSWD='${WRT_DEF_PASSWD:-"luc1-r00t+pa5Swd"}'
export WRT_LUCI_CGI='${WRT_LUCI_CGI:-"cgi-bin"}'
export WRT_LUCI_STA='${WRT_LUCI_STA:-"luci-static"}'
export WRT_URI_3X_UI='${WRT_URI_3X_UI:-"3xui"}'
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
export WRT_COUCH_URI='${WRT_COUCH_URI:-"s3cre1patht0som3couchDataba5e"}'
export WRT_AUTHELIA_URI='${WRT_AUTHELIA_URI:-"s3cre1pathtAuthe1iaURI4pr0tect"}'
export WRT_AUTHELIA_JWT='${WRT_AUTHELIA_JWT:-"s3cre1jwt0kenAuthe1ia4pr0tect"}'
export WRT_AUTHELIA_SES='${WRT_AUTHELIA_SES:-"s3cre1se5si0ntAuthe1ia4pr0tect"}'
export WRT_AUTHELIA_DBKEY='${WRT_AUTHELIA_DBKEY:-"s3cre1DaTabKe4Authe1ia4pr0tect"}'
export WRT_L2TP_SERVER='${WRT_L2TP_SERVER:-"123.321.231.132"}'
export WRT_L2TP_LOGIN='${WRT_L2TP_LOGIN:-"l2tp-user"}'
export WRT_L2TP_PASSWD='${WRT_L2TP_PASSWD:-"l2tp-password"}'
export WRT_IPSEC_PSK='${WRT_IPSEC_PSK:-"s3cre1P5k4ipSek4pr0tect"}'
export WRT_CLIENTS='${WRT_CLIENTS:-"caga@50:e5:49:cb:b5:67#1,
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
  /usr/bin/env bash -c " \
  cp -v /files/etc/opkg/distfeeds.conf /builder/repositories.conf &&
  make image PROFILE='bananapi_bpi-r3' FILES='/files' \
  ROOTFS_PARTSIZE='1111' EXTRA_PARTSIZE='6111' \
  PACKAGES='-dnsmasq atop lsblk mmc-utils ca-certificates bsdtar ack mtr-json haproxy \
  acme-acmesh-dnsapi netatop bash bind-dig bind-host bind-nslookup bird2 bird2c bird2cl \
  blkid block-mount bsdiff bspatch btop cfdisk cgdisk clocate conntrack ctop curl \
  ddns-scripts-cloudflare diffutils dnscrypt-proxy2 dnsmasq-full docker docker-compose \
  dockerd ethtool fail2ban fdisk file findutils-find findutils-locate findutils-xargs \
  flock fping gawk gdisk git grep hping3 htop iftop iperf iperf3 iputils-arping \
  iputils-clockdiff iputils-ping iputils-tracepath jool-tools-netfilter jq less libgcc \
  libustream-mbedtls lm-sensors logger losetup monit moreutils msmtp msmtp-queue \
  mutt nand-utils netcat nfdump nftables openssh-sftp-server openssl-util parted patch \
  podman pv python3 resize2fs rsync sed sfdisk socksify softflowd ss strace stubby tar \
  tcpdump telnet-bsd terminfo tmux vim-fuller wg-installer-client whereis whois \
  wireguard-tools xzdiff xzgrep xzless yq zoneinfo-all zram-swap lz4 zstd unrar \
  logrotate nmap-full xl2tpd strongswan-full \
  \
  coreutils coreutils-b2sum coreutils-base32 coreutils-base64 coreutils-basename \
  coreutils-basenc coreutils-cat coreutils-chcon coreutils-chgrp coreutils-chmod \
  coreutils-chown coreutils-chroot coreutils-cksum coreutils-comm coreutils-cp \
  coreutils-csplit coreutils-cut coreutils-date coreutils-dd coreutils-df coreutils-dir \
  coreutils-dircolors coreutils-dirname coreutils-du coreutils-echo coreutils-env \
  coreutils-expand coreutils-expr coreutils-factor coreutils-false coreutils-fmt \
  coreutils-fold coreutils-groups coreutils-head coreutils-hostid coreutils-id \
  coreutils-install coreutils-join coreutils-kill coreutils-link coreutils-ln \
  coreutils-logname coreutils-ls coreutils-md5sum coreutils-mkdir coreutils-mkfifo \
  coreutils-mknod coreutils-mktemp coreutils-mv coreutils-nice coreutils-nl \
  coreutils-nohup coreutils-nproc coreutils-numfmt coreutils-od coreutils-paste \
  coreutils-pathchk coreutils-pinky coreutils-pr coreutils-printenv coreutils-printf \
  coreutils-ptx coreutils-pwd coreutils-readlink coreutils-realpath coreutils-rm \
  coreutils-rmdir coreutils-runcon coreutils-seq coreutils-sha1sum coreutils-sha224sum \
  coreutils-sha256sum coreutils-sha384sum coreutils-sha512sum coreutils-shred \
  coreutils-shuf coreutils-sleep coreutils-sort coreutils-split coreutils-stat \
  coreutils-stdbuf coreutils-stty coreutils-sum coreutils-sync coreutils-tac \
  coreutils-tail coreutils-tee coreutils-test coreutils-timeout coreutils-touch \
  coreutils-tr coreutils-true coreutils-truncate coreutils-tsort coreutils-tty \
  coreutils-uname coreutils-unexpand coreutils-uniq coreutils-unlink coreutils-uptime \
  coreutils-users coreutils-vdir coreutils-wc coreutils-who coreutils-whoami \
  coreutils-yes net-tools-route \
  \
  kmod-nft-tproxy kmod-tun stress-ng stress \
  \
  shadow-chpasswd shadow-chsh shadow-passwd shadow-usermod \
  \
  luci luci-app-acme luci-app-ddns luci-mod-dashboard luci-proto-wireguard \
  luci-ssl-nginx luci-app-uhttpd \
  \
  procps-ng-free procps-ng-kill procps-ng-pgrep procps-ng-pkill procps-ng-pmap \
  procps-ng-ps procps-ng-pwdx procps-ng-skill procps-ng-slabtop procps-ng-snice \
  procps-ng-sysctl procps-ng-top procps-ng-uptime procps-ng-vmstat procps-ng-w \
  procps-ng-watch \
  \
  prometheus-node-exporter-lua prometheus-node-exporter-lua-nat_traffic \
  prometheus-node-exporter-lua-netstat prometheus-node-exporter-lua-openwrt \
  prometheus-node-exporter-lua-thermal prometheus-node-exporter-lua-wifi \
  prometheus-node-exporter-lua-wifi_stations \
  ' \
"
/usr/bin/env sudo chown -R "${USER}" release
