# My config of OpenWRT image for BPI-R3 board

[![Build status](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml/badge.svg)](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml)

## Build steps

- clone me:

  ```bash
  git clone --recursive \
  git@github.com:raven428/green-wire.git \
  green-wire && cd green-wire
  ```

- set [secrets for `build.sh`](build.sh#L59-L93) in `green-wise/OpenWRT/name.sh`
- build images

  ```bash
  VER=025 ./build.sh
  ```

- or make tag and send to release:

  ```bash
  git checkout master && git pull
  git tag -fm $(git branch --sho) 025 && git push origin --force $(git describe)
  ```

- flash image

  ```bash
  # either eMMC:
  dd if=upload/bpi_r3-rel${VER}-name-*-image.img of=/dev/mmcblk0

  # or sdcard:
  dd if=upload/bpi_r3-rel${VER}-name-*-image.img of=/dev/sda
  ```

  Also, `upload/bpi_r3-rel${VER}-name-*-sysupgrade.itb` could be installed through sysupgrade. However, no re-partition will be performed in this case
