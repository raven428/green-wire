#!/usr/bin/env bash
set -uo pipefail
fifo='/var/run/ovepn.auth'
cred_file='/etc/openvpn/ovepn.cred'
key_file='/etc/openvpn/ovepn.totp'
args_file='/etc/openvpn/ovepn.oath'
log() {
  echo "${*}" | /usr/bin/env logger -t 'ovepn-auth'
}
for f in "${cred_file}" "${key_file}" "${args_file}"; do
  [[ -r "${f}" ]] || {
    log "file [${f}] isn't readable"
    /usr/bin/env sleep 5
    exit 1
  }
done
[[ -p "${fifo}" ]] || {
  /usr/bin/env rm -f "${fifo}"
  /usr/bin/env mkfifo -m 600 "${fifo}" || exit 1
}
login=''
passwd=''
{
  IFS= read -r login
  IFS= read -r passwd
} <"${cred_file}"
mapfile -t oath_args <"${args_file}"
last_otp=''
# servers reject reused codes, so wait for the next one after delivered
new_otp() {
  local code
  while code="$(/usr/bin/oathtool "${oath_args[@]}" "@${key_file}")" &&
    [[ -n "${code}" ]]; do
    [[ "${code}" != "${last_otp}" ]] && echo "${code}" && return 0
    /usr/bin/env sleep 1
  done
  return 1
}
# reader may close fifo before write, keep running on EPIPE
trap '' PIPE
while true; do
  delivered='no'
  # opening fifo blocks until openvpn opens it for reading, so otp is fresh
  {
    if otp="$(new_otp)"; then
      /usr/bin/env printf '%s\n%s%s\n' "${login}" "${passwd}" "${otp}" &&
        delivered='yes' && last_otp="${otp}"
    else
      log 'oathtool failed, nothing delivered'
    fi
  } >"${fifo}" || log "can't open [${fifo}]"
  if [[ "${delivered}" == 'yes' ]]; then
    # let reader close fifo before next open
    /usr/bin/env sleep 1
  else
    /usr/bin/env sleep 5
  fi
done
