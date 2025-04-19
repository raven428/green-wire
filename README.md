# My config of OpenWRT image for BPI-R3 board

[![Build status](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml/badge.svg)](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml)

## Build steps

- clone me:

  ```bash
  git clone --recursive \
  git@github.com:raven428/green-wire.git \
  green-wire && cd green-wire
  ```

- set [secrets for `build.sh`](build.sh#L60-L105) in `green-wise/OpenWRT/name.sh`
- build images

  ```bash
  VER=027 ./build.sh
  ```

- or make tag and send to release:

  ```bash
  git checkout master && git pull
  git tag -fm $(git branch --sho) 027 && git push origin --force $(git describe)
  ```

## Clean eMMC install steps

- flash sdcard image `dd if=bpi_r3-rel${VER}-name-*-install.img of=/dev/sda`

- boot from sdcard with H-H-H-H switchers

- install to NAND from the boot menu

- boot from NAND with H-L-H-L switchers

- install to eMMC from the boot menu

- boot from eMMC with L-H-H-L switchers

- perform `sysupgrade` with `bpi_r3-rel${VER}-name-*-sysupgrade.itb`
