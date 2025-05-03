#!/usr/bin/env bash
export WRT_HOSTNAME='garden'
export WRT_WIFI_SSID="${WRT_HOSTNAME}"
export WRT_ARCH='aarch64_cortex-a53'
export WRT_BOARD='sunxi/cortexa53'
export WRT_KMODS='6.6.86-1-d0617ab163ece80de863452c22026024'
export WRT_BUILDER='ghcr.io/raven428/container-images/owrt-sxi-cora53-24_10_1:000'
export WRT_PROFILE='xunlong_orangepi-zero3'
export WRT_LAN2WAN_TAG='null'
# export WRT_ACME_STAR='null' – use default null
export WRT_SIZE_ROOT='2222'
export WRT_PORT_FORWARD='null'
export WRT_ADD_PKGS=''
export WRT_SKIP_INSTALLER='yes'
export WRT_SIZE_EXTRA='12222'
export WRT_CO_SUFFIX='op3z'
