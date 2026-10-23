#!/usr/bin/env bash
export WRT_HOSTNAME='werter'
export WRT_WIFI_SSID="${WRT_HOSTNAME}"
export WRT_ARCH='aarch64_cortex-a53'
export WRT_BOARD='mediatek/filogic'
export WRT_KMODS='6.6.86-1-6ace983a14b769f576fe9c4c7961bd89'
export WRT_BUILDER='ghcr.io/megalomania428/owrt-mtk-filogic-24_10_1:latest'
export WRT_PROFILE='bananapi_bpi-r3'
export WRT_WIFI_MAC_FILTER='allow'
export WRT_LAN2WAN_TAG='yes'
export WRT_ACME_STAR='yes'
export WRT_SIZE_ROOT='2222'
# export WRT_PORT_FORWARD='null' – use defaults from build.sh
export WRT_ADD_PKGS='nand-utils kmod-nvme'
