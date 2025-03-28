# My config of OpenWRT image for BPI-R3 board

[![Build status](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml/badge.svg)](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml)

## Build steps

- clone me:

  ```bash
  git clone --recursive \
  git@github.com:raven428/green-wire.git \
  green-wire && cd green-wire
  ```

- set [secrets for `build.sh`](build.sh#L41-L71) in `green-wise/OpenWRT/name.sh`
- build images

  ```bash
  VER=024 ./build.sh
  ```

- or make tag and send to release:

  ```bash
  export VER=024 && git checkout master && git pull
  git tag -fm master ${VER} && git push --force origin ${VER}
  ```

- flash image

  ```bash
  # either eMMC:
  dd if=upload/bpi_r3-rel${VER}-name-*-image.img of=/dev/mmcblk0

  # or sdcard:
  dd if=upload/bpi_r3-rel${VER}-name-*-image.img of=/dev/sda
  ```

  Also, `upload/bpi_r3-rel${VER}-name-*-sysupgrade.itb` could be installed through sysupgrade. However, no re-partition will be performed in this case
