#!/usr/bin/env bash
export WRT_HOSTNAME='hearts'
export WRT_WIFI_SSID="${WRT_HOSTNAME}"
export WRT_ARCH='aarch64_cortex-a53'
export WRT_BOARD='mediatek/filogic'
export WRT_KMODS='6.6.86-1-6ace983a14b769f576fe9c4c7961bd89'
export WRT_BUILDER='ghcr.io/raven428/container-images/owrt-mtk-filogic-24_10_1:000'
export WRT_PROFILE='bananapi_bpi-r3'
export WRT_LAN2WAN_TAG='null'
# export WRT_ACME_STAR='null' – use default null
export WRT_SIZE_ROOT='2222'
export WRT_PORT_FORWARD='null'
export WRT_ADD_PKGS='nand-utils kmod-nvme'
