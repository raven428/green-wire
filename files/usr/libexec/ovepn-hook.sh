#!/usr/bin/env bash
set -uo pipefail
action="${1:-}"
nftset='ovepn4dst'
nftset_file='/var/run/ovepn4dst.txt'
dnsmasq_conf='/etc/dnsmasq.d/ovepn.conf'
tmp_dnsmasq_conf='/var/tmp/dnsmasq-ovepn.conf'
# canonical octets only: dnsmasq and nft reject leading zeros and values above 255
octet_re='(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])'
ipv4_re="^${octet_re}(\\.${octet_re}){3}$"
mask2prefix() {
  local octet prefix=0
  local -a octets
  IFS='.' read -ra octets <<<"${1}"
  for octet in "${octets[@]}"; do
    while ((octet > 0)); do
      prefix=$((prefix + (octet & 1)))
      octet=$((octet >> 1))
    done
  done
  echo "${prefix}"
}
# set variable ${2} to address ${1} as integer, without fork
ip2int() {
  local a b c d="${1}"
  a="${d%%.*}" d="${d#*.}"
  b="${d%%.*}" d="${d#*.}"
  c="${d%%.*}" d="${d#*.}"
  printf -v "${2}" '%d' $(((10#${a} << 24) | (10#${b} << 16) | (10#${c} << 8) | 10#${d}))
}
# true if network ${1} with prefix ${2} contains address ${3}
net_has_ip() {
  local mask net_int ip_int
  mask=$(((0xffffffff << (32 - ${2})) & 0xffffffff))
  ip2int "${1}" net_int
  ip2int "${3}" ip_int
  (((net_int & mask) == (ip_int & mask)))
}
# remove elements added by previous route-up, keep others
del_elements() {
  local dst
  [[ -f "${nftset_file}" ]] || return 0
  while IFS= read -r dst; do
    [[ -n "${dst}" ]] || continue
    /usr/sbin/nft delete element inet fw4 "${nftset}" "{ ${dst} }" ||
      echo "can't delete [${dst}] from [${nftset}]"
  done <"${nftset_file}"
  /usr/bin/env rm -f "${nftset_file}"
}
case "${action}" in
route-up)
  # pushed routes via net_gateway are exceptions from the tunnel
  net_gw="${route_net_gateway:-}"
  dns_list=()
  domains=()
  for ((i = 1; ; i++)); do
    var="foreign_option_${i}"
    [[ -v "${var}" ]] || break
    read -r opt kind value _ <<<"${!var}"
    [[ "${opt}" == 'dhcp-option' ]] || continue
    case "${kind}" in
    DNS) [[ "${value}" =~ ${ipv4_re} ]] && dns_list+=("${value}") ;;
    DOMAIN) [[ -n "${value}" ]] && domains+=("${value}") ;;
    esac
  done
  IFS=', ' read -ra extra <<<"${ovepn_domains:-}"
  for domain in "${extra[@]}"; do
    [[ -n "${domain}" ]] && domains+=("${domain}")
  done
  # both pushed halves of ipv4 are the same as redirect-gateway def1
  halves=0
  for ((i = 1; ; i++)); do
    net_var="route_network_${i}"
    mask_var="route_netmask_${i}"
    [[ -v "${net_var}" ]] || break
    [[ "${!mask_var:-}" == '128.0.0.0' ]] || continue
    case "${!net_var}" in
    0.0.0.0) halves=$((halves | 1)) ;;
    128.0.0.0) halves=$((halves | 2)) ;;
    esac
  done
  dst_list=()
  excl_list=()
  for ((i = 1; ; i++)); do
    net_var="route_network_${i}"
    mask_var="route_netmask_${i}"
    [[ -v "${net_var}" ]] || break
    gw_var="route_gateway_${i}"
    net="${!net_var}"
    [[ "${net}" =~ ${ipv4_re} ]] || continue
    prefix="$(mask2prefix "${!mask_var:-255.255.255.255}")"
    if [[ -n "${net_gw}" && "${!gw_var:-}" == "${net_gw}" ]]; then
      echo "skip route [${net}/${prefix}] via net_gateway [${net_gw}]"
      excl_list+=("${net}/${prefix}")
    elif ((prefix == 0 || (prefix == 1 && halves == 3))); then
      echo "skip default route [${net}/${prefix}]"
    else
      dst_list+=("${net}/${prefix}")
    fi
  done
  # nested networks would break deletion from auto-merged set, keep the widest
  addrs=()
  prefixes=()
  for n in "${dst_list[@]}"; do
    ip2int "${n%/*}" addr
    # shellcheck disable=2154
    addrs+=("${addr}")
    prefixes+=("${n#*/}")
  done
  nets=()
  for ((i = 0; i < ${#dst_list[@]}; i++)); do
    n="${dst_list[i]}"
    covered=''
    for ((j = 0; j < ${#dst_list[@]}; j++)); do
      p="${prefixes[j]}"
      ((i != j && (p < prefixes[i] || (p == prefixes[i] && j < i)))) || continue
      if ((((addrs[i] ^ addrs[j]) & (0xffffffff << (32 - p)) & 0xffffffff) == 0)); then
        covered="${dst_list[j]}"
        break
      fi
    done
    if [[ -n "${covered}" ]]; then
      echo "skip route [${n}] covered by [${covered}]"
    else
      nets+=("${n}")
    fi
  done
  dst_list=("${nets[@]}")
  for dns in "${dns_list[@]}"; do
    covered=''
    for n in "${dst_list[@]}"; do
      if [[ "${n}" == */* ]]; then
        net_has_ip "${n%/*}" "${n#*/}" "${dns}" && covered="${n}"
      elif [[ "${n}" == "${dns}" ]]; then
        covered="${n}"
      fi
    done
    for n in "${excl_list[@]}"; do
      net_has_ip "${n%/*}" "${n#*/}" "${dns}" && covered="${n} via net_gateway"
    done
    if [[ -n "${covered}" ]]; then
      echo "skip dns [${dns}] covered by [${covered}]"
    else
      dst_list+=("${dns}")
    fi
  done
  del_elements
  : >"${nftset_file}"
  for dst in "${dst_list[@]}"; do
    if /usr/sbin/nft add element inet fw4 "${nftset}" "{ ${dst} }"; then
      echo "${dst}" >>"${nftset_file}"
    else
      echo "can't add [${dst}] to [${nftset}]"
    fi
  done
  echo "[${dst_list[*]}] added to [${nftset}]"
  /usr/bin/env touch "${dnsmasq_conf}"
  /usr/bin/truncate -s 0 "${tmp_dnsmasq_conf}"
  for domain in "${domains[@]}"; do
    for dns in "${dns_list[@]}"; do
      echo "server=/${domain}/${dns}" >>"${tmp_dnsmasq_conf}"
    done
  done
  /usr/bin/env diff -u "${dnsmasq_conf}" "${tmp_dnsmasq_conf}" || {
    /usr/bin/env cp -v "${tmp_dnsmasq_conf}" "${dnsmasq_conf}"
    /etc/init.d/dnsmasq restart
  }
  ;;
route-pre-down | down)
  del_elements
  echo "elements of [${nftset}] removed"
  if [[ -s "${dnsmasq_conf}" ]]; then
    /usr/bin/env rm -fv "${dnsmasq_conf}"
    /etc/init.d/dnsmasq restart
  else
    /usr/bin/env rm -f "${dnsmasq_conf}"
  fi
  ;;
esac
