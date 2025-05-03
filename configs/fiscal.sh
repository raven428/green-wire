#!/usr/bin/env bash
export WRT_HOSTNAME='fiscal'
export WRT_WIFI_SSID="${WRT_HOSTNAME}"
export WRT_ARCH='aarch64_generic'
export WRT_BOARD='rockchip/armv8'
export WRT_KMODS='6.6.86-1-a8e18e0ecc66cc99303d258424ec0db8'
export WRT_BUILDER='ghcr.io/raven428/container-images/owrt-rock-armv8-24_10_1:000'
export WRT_PROFILE='friendlyarm_nanopi-r3s'
export WRT_LAN2WAN_TAG='null'
# export WRT_ACME_STAR='null' – use default null
export WRT_SIZE_ROOT='2222'
export WRT_PORT_FORWARD='null'
export WRT_ADD_PKGS=''
export WRT_SKIP_INSTALLER='yes'
export WRT_SIZE_EXTRA='12222'
export WRT_CO_SUFFIX='nr3s'
