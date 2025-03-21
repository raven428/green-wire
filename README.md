# My config of OpenWRT image for BPI-R3 board

[![Build status](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml/badge.svg)](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml)

## Build steps

- clone me:

  ```bash
  git clone --recursive \
  git@github.com:raven428/green-wire.git \
  green-wire && cd green-wire
  ```

- set [secrets for `build.sh`](build.sh#L6-L33)
- build images

  ```bash
  VER=023 ./build.sh
  ```

- make tag and send to release:

  ```bash
  export VER=023 && git checkout master && git pull
  git tag -fm master ${VER} && git push --force origin ${VER}
  ```

- flash image

  ```bash
  # either eMMC:
  dd if=openwrt-23.05.5-mediatek-filogic-bananapi_bpi-r3-sdcard.img of=/dev/mmcblk0

  # or sdcard:
  dd if=openwrt-23.05.5-mediatek-filogic-bananapi_bpi-r3-sdcard.img of=/dev/sda
  ```
