#!/usr/bin/env bash
set -ueo pipefail
[[ -d 'green-wise' ]] ||
  /usr/bin/env git clone "https://${GITHUB_TOKEN}@github.com/raven428/green-wise.git"
file_base=${NAME2BUILD:-"werter"}
conf_file="green-wise/OpenWRT/${file_base}.sh"
# shellcheck source=/dev/null
source "${conf_file}"
: "${VER:="999"}"
: "${WRT_HOSTNAME:="werter"}"
: "${WRT_OPKG_REPO:="downloads.openwrt.org"}"
: "${DISABLED_SERVICES:="dockerd podman bird monit softflowd nfcapd tun2ray nginx \
authelia swanctl"}"
secrets="$(/usr/bin/env grep -E '^export\s+WRT' "${conf_file}" |
  /usr/bin/env sed -E 's/^export\s+WRT_([a-z0-9_]+)=.+/\1/i')"
for secret in ${secrets}; do
  current_var='vault'
  eval "current_var=\"\$WRT_${secret}\""
  [[ "${current_var}" == 'vault' ]] && [[ -v 'INFISICAL_TOKEN' ]] && {
    current_var="$(
      /usr/bin/env curl -Lm 33 --request GET \
        --header "Authorization: Bearer ${INFISICAL_TOKEN}" \
        --url "https://us.infisical.com/api/v3/secrets/raw/\
grewi-${file_base}-${secret}" \
        2>/dev/null |
        /usr/bin/env jq -r '.secret.secretValue'
    )"
    [[ "${current_var}" == 'null' ]] && {
      echo "Vault of [${secret}] is null. Giving up…"
      exit 1
    }
    eval "export WRT_${secret}='${current_var}'"
  }
  [[ "${current_var}" != 'null' && "${current_var}" != "${file_base}" ]] &&
    /usr/bin/env printf "::add-mask::%s\n" "$(
      echo "${current_var}" |
        /usr/bin/env tr -d '\n'
    )"
done
# shellcheck disable=2086
IFS=',' read -ra array <<<"$(echo -n ${WRT_CLIENTS})"
for c in "${array[@]}"; do
  name="${c%@*}"
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  temp="${c#*@}"
  mac="${temp%#*}"
  mac="${mac#"${mac%%[![:space:]]*}"}"
  mac="${mac%"${mac##*[![:space:]]}"}"
  echo "::add-mask::${name}"
  for m in ${mac}; do
    echo "::add-mask::${m}"
  done
done
/usr/bin/env printf "\n———⟨ building [%s] image ⟩———\n" "${file_base}"
/usr/bin/env rm -rf prepare release
/usr/bin/env cp -r files prepare
/usr/bin/env cat <<EOF >prepare/etc/secrets.sh
export WRT_GREWIBU='${VER}'
export WRT_ROOT_PASSWD='${WRT_DEF_PASSWD:-"luc1-r00t+pa5Swd"}'
export WRT_LUCI_CGI='${WRT_LUCI_CGI:-"cgi-bin"}'
export WRT_LUCI_STA='${WRT_LUCI_STA:-"luci-static"}'
export WRT_URI_3X_UI='${WRT_URI_3X_UI:-"3xui"}'
export WRT_CLOFA_TO='${WRT_CLOFA_TO:-"cloudflare-token-for-ddns"}'
export WRT_CLOFA_ZO='${WRT_CLOFA_ZO:-"cloudflare-zone-for-ddns"}'
export WRT_SMTP_HOST='${WRT_SMTP_HOST:-"smtp-relay-host"}'
export WRT_SMTP_LOGIN='${WRT_SMTP_LOGIN:-"smtp-relay-login"}'
export WRT_SMTP_PASSWD='${WRT_SMTP_PASSWD:-"smtp-relay-password"}'
export WRT_DEVICE_MAC='${WRT_DEVICE_MAC:-"01:a2:b3:c4:d6:e6"}'
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
export WRT_L2TP_SERVER='${WRT_L2TP_SERVER:-"10.23.45.67"}'
export WRT_L2TP_LOGIN='${WRT_L2TP_LOGIN:-"l2tp-user"}'
export WRT_L2TP_PASSWD='${WRT_L2TP_PASSWD:-"l2tp-password"}'
export WRT_LAN2WAN_TAG='${WRT_LAN2WAN_TAG:-"null"}'
export WRT_ACME_STAR='${WRT_ACME_STAR:-"null"}'
export WRT_IPSEC_PSK='${WRT_IPSEC_PSK:-"s3cre1P5k4ipSek4pr0tect"}'
export WRT_WARP_REGIONS='${WRT_WARP_REGIONS:-"m"}'
export WRT_WARP_REG='${WRT_WARP_REG:-"172.16.0.2,26:06:47::00,private_key"}'
export WRT_OTHER_ROUTES='${WRT_OTHER_ROUTES:-"tr cy kz ge de us ng cl bg it ar uy \
se nl cz"}'
export WRT_CLIENTS='${WRT_CLIENTS:-"caga@50:e5:49:cb:b5:67#1,
dir300@00:21:91:31:98:60#99"}'
EOF
/usr/bin/env rm -rfv prepare/root/dot-git
/usr/bin/env cp -r .git/modules/files/root prepare/root/dot-git
/usr/bin/env cat <<EOF >prepare/root/dot-git/config
[core]
repositoryformatversion = 0
filemode = true
bare = false
logallrefupdates = true
[remote "origin"]
url = git@github.com:raven428/profile.git
fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
remote = origin
merge = refs/heads/master
[log]
showSignature = false
[user]
name = Dmitry Sukhodoev
email = raven428@gmail.com
EOF
for f in prepare/etc/dnsmasq.d/*.sets; do
  r="${f##*/}"
  r="${r%.*}"
  /usr/bin/env sed -E "/^[[:space:]]*#/b ; /^[[:space:]]*$/b ;
  s~^(.*)$~nftset=/\1/4#inet#fw4#vpn4_${r},6#inet#fw4#vpn6_${r}~
" -i "${f}"
done
/usr/bin/env mkdir -vp prepare/etc/opkg
r="https://${WRT_OPKG_REPO}/releases/23.05.5"
/usr/bin/env cat <<EOF >prepare/etc/opkg/distfeeds.conf
src/gz openwrt_core      ${r}/targets/mediatek/filogic/packages
src/gz openwrt_base      ${r}/packages/aarch64_cortex-a53/base
src/gz openwrt_luci      ${r}/packages/aarch64_cortex-a53/luci
src/gz openwrt_routing   ${r}/packages/aarch64_cortex-a53/routing
src/gz openwrt_packages  ${r}/packages/aarch64_cortex-a53/packages
src/gz openwrt_telephony ${r}/packages/aarch64_cortex-a53/telephony
EOF
[[ ${WRT_IPSEC_PSK:-"null"} != 'null' &&
  ${WRT_L2TP_SERVER:-"null"} != 'null' ]] ||
  DISABLED_SERVICES="${DISABLED_SERVICES} ipsec"
[[ ${WRT_L2TP_LOGIN:-"null"} != 'null' &&
  ${WRT_L2TP_PASSWD:-"null"} != 'null' &&
  ${WRT_L2TP_SERVER:-"null"} != 'null' ]] ||
  DISABLED_SERVICES="${DISABLED_SERVICES} xl2tpd"
/usr/bin/env docker run --user 0 --rm -i --network=host --name=openwrt-builder \
  -v "$(pwd)"/prepare:/files:rw \
  -v "$(pwd)"/release:/builder/bin/targets/mediatek/filogic:rw \
  ghcr.io/raven428/container-images/openwrt-imagebuilder/mediatek-filogic-23_05_5 \
  /usr/bin/env bash -c " \
  cp -v /files/etc/opkg/distfeeds.conf /builder/repositories.conf &&
  make image PROFILE='bananapi_bpi-r3' FILES='/files' ROOTFS_PARTSIZE='2222' \
  EXTRA_PARTSIZE='5155' EXTRA_IMAGE_NAME='rel${VER}-${WRT_HOSTNAME}' \
  DISABLED_SERVICES='${DISABLED_SERVICES}' \
  PACKAGES='-dnsmasq atop lsblk mmc-utils ca-certificates bsdtar ack mtr-json haproxy \
  acme-acmesh-dnsapi netatop bind-dig bind-host bind-nslookup bird2 bird2c bird2cl \
  blkid block-mount bsdiff bspatch btop cfdisk cgdisk clocate conntrack ctop iconv \
  ddns-scripts-cloudflare diffutils dnscrypt-proxy2 dnsmasq-full docker docker-compose \
  dockerd ethtool fail2ban fdisk file findutils-find findutils-locate findutils-xargs \
  flock fping gawk gdisk git grep hping3 htop iftop iperf iperf3 iputils-arping bwm-ng \
  iputils-clockdiff iputils-ping iputils-tracepath jool-tools-netfilter jq less libgcc \
  libustream-mbedtls lm-sensors logger losetup monit moreutils msmtp msmtp-queue bmon \
  mutt nand-utils netcat nfdump nftables openssh-sftp-server openssl-util parted patch \
  podman pv python3 resize2fs rsync sed sfdisk socksify softflowd ss strace stubby tar \
  tcpdump telnet-bsd terminfo tmux vim-fuller wg-installer-client whereis whois \
  wireguard-tools xzdiff xzgrep xzless yq zoneinfo-all zram-swap lz4 zstd unrar \
  logrotate nmap-full xl2tpd strongswan-full sudo prlimit bash curl stress-ng stress \
  usbutils smartmontools xfs-mkfs xfs-fsck xfs-admin xfs-growfs nvme-cli progress tree \
  pigz \
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
  coreutils-uname coreutils-unexpand coreutils-uniq coreutils-unlink psmisc \
  coreutils-users coreutils-vdir coreutils-wc coreutils-who coreutils-whoami \
  coreutils-yes net-tools-route \
  \
  kmod-nft-tproxy kmod-dummy kmod-tun kmod-usb-storage kmod-fs-vfat kmod-fs-exfat \
  kmod-fs-msdos kmod-fs-xfs kmod-fs-ext4 kmod-fs-f2fs kmod-fs-ntfs kmod-fs-ntfs3 \
  kmod-nvme \
  \
  shadow-chpasswd shadow-chsh shadow-passwd shadow-usermod \
  \
  luci luci-app-acme luci-app-ddns luci-mod-dashboard luci-proto-wireguard \
  luci-ssl-nginx luci-app-uhttpd luci-app-statistics luci-app-vnstat2 \
  luci-app-nlbwmon \
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
  \
  collectd-mod-conntrack collectd-mod-contextswitch collectd-mod-dhcpleases \
  collectd-mod-uptime collectd-mod-thermal collectd-mod-cpufreq collectd-mod-entropy \
  collectd-mod-exec collectd-mod-interface collectd-mod-ipstatistics collectd-mod-irq \
  collectd-mod-netlink collectd-mod-processes collectd-mod-tcpconns collectd-mod-thermal \
  collectd-mod-uptime collectd-mod-dns collectd-mod-ethstat collectd-mod-filecount \
  collectd-mod-fscache collectd-mod-ntpd collectd-mod-protocols collectd-mod-swap \
  collectd-mod-users collectd-mod-vmem collectd-mod-wireless collectd-mod-sensors \
  ' \
"
/usr/bin/env sudo chown -R "${USER}" release
# shellcheck disable=2016
device_id="$(
  /usr/bin/env jq -r '.profiles[] |
  .supported_devices[]' release/profiles.json |
    /usr/bin/env tail -1 |
    /usr/bin/env awk -F ',' '{ print $NF }'
)"
image_prefix="$(
  /usr/bin/env jq -r '.profiles[] | .image_prefix' release/profiles.json |
    /usr/bin/env tail -1
)"
version_code="$(/usr/bin/env jq -r '.version_code' release/profiles.json)"
version_number="$(/usr/bin/env jq -r '.version_number' release/profiles.json)"
/usr/bin/env printf "i[%s] p[%s] c[%s] n[%s]\n" \
  "${device_id:-null}" "${image_prefix:-null}" \
  "${version_code:-null}" "${version_number:-null}"
[[ "${device_id:-null}" == "null" ||
  "${image_prefix:-null}" == "null" ||
  "${version_code:-null}" == "null" ||
  "${version_number:-null}" == "null" ]] &&
  {
    echo 'Some fields of profiles.json are [null] or not exist. Giving up…'
    exit 2
  }
/usr/bin/env mkdir -vp "upload"
dest_prefix="upload/${device_id//[^0-9a-zA-Z]/_}-rel${VER}-${file_base}-\
${version_number//[^0-9a-zA-Z]/_}-${version_code//[^0-9a-zA-Z]/_}"
/usr/bin/env cp -vf "release/${image_prefix}-squashfs-sysupgrade.itb" \
  "${dest_prefix}-sysupgrade.itb"
/usr/bin/env zcat "release/${image_prefix}-sdcard.img.gz" >"${dest_prefix}-image.img"
(
  cd release
  /usr/bin/env tar --xz --create --file "../${dest_prefix}-etc.txz" etc
)
