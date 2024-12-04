#!/usr/bin/env bash
set -ueo pipefail
: "${XUI:="3x-ui"}"
: "${XUIV:="${XUI}-2_4_5-arm64-static-musl"}"
: "${XURI:="https://github.com/raven428/container-images/releases/download/000/${XUIV}.tar.xz"}"
: 
if [[ -n "${WRT_SET_PASSWD:-}" ]]; then
  /usr/bin/env printf "${WRT_SET_PASSWD}\n${WRT_SET_PASSWD}\n" |
    /usr/bin/env passwd
else
  echo "skipped passwd, [export WRT_SET_PASSWD=pwd4dev] to set "
fi
(
  /usr/bin/env mkdir -vp /opt/3x-ui/bin
  cd /opt/3x-ui
  /usr/bin/env curl -Lm 11 -o - "${XURI}" |
    /bin/tar xJvf -
  /usr/bin/env ln -sfv "${XUIV}" "${XUI}"
)
