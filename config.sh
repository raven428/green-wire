#!/usr/bin/env bash
set -ueo pipefail
: "${XUI:="3x-ui"}"
: "${XUIV:="${XUI}-2_4_5-arm64-static-musl"}"
: "${XURI:="https://github.com/raven428/container-images/releases/download/000/${XUIV}.tar.xz"}"
: "${T2S:="tun2socks"}"
: "${T2SV:="tun2socks-linux-arm64"}"
: "${T2SU:="https://github.com/xjasonlyu/tun2socks/releases/download/v2.5.2/tun2socks-linux-arm64.zip"}"
if [[ -n "${WRT_SET_PASSWD:-}" ]]; then
  /usr/bin/env printf "${WRT_SET_PASSWD}\n${WRT_SET_PASSWD}\n" |
    /usr/bin/env passwd
else
  echo "skipped passwd, [export WRT_SET_PASSWD=pwd4dev] to set "
fi
(
  /usr/bin/env mkdir -vp /opt/3x-ui/bin
  cd /opt/3x-ui
  /usr/bin/env curl -Lm 111 -o - "${XURI}" |
    /usr/bin/env bsdtar xJvf -
  /usr/bin/env ln -sfv "${XUIV}" "${XUI}"
)
(
  /usr/bin/env mkdir -vp /opt/bin/
  cd /opt/bin
  /usr/bin/env curl -Lm 111 -o - "${T2SU}" |
    /usr/bin/bsdtar xvf -
  /usr/bin/env mv -fv "${T2SV}" "${T2S}"
  /usr/bin/env chmod 755 "${T2S}"
)
