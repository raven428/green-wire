# My config of OpenWRT image for BPI-R3 board

[![Build status](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml/badge.svg)](https://github.com/raven428/green-wire/actions/workflows/test-build.yaml)

## Build steps

- clone me:

  ```bash
  git clone --recursive \
  git@github.com:raven428/green-wire.git \
  green-wire && cd green-wire
  ```

- set [secrets for `build.sh`](build.sh#L86-L129) in `green-wise/OpenWRT/name.sh`
- build images

  ```bash
  VER=031 ./build.sh
  ```

- or make tag and send to release:

  ```bash
  git checkout master && git pull
  git tag -fm $(git branch --sho) 031 && git push origin --force $(git describe)
  ```

## Rust binaries

Rust packages live in the `rust/` workspace, every package builds one binary of the same name
and keeps the `999.9.9` placeholder version in its `Cargo.toml`. `build.sh` compiles the workspace
in the `docker.io/library/rust:<version>-slim` container, where the version comes from
`rust/rust-toolchain.toml`, and places binaries into the image by the explicit `rust_bins` list.

- build locally:

  ```bash
  cd rust && cargo build --release --locked --target aarch64-unknown-linux-musl
  ```

- `rust.sh` checks formatting, runs tests and then builds every package one by one in the same
  container: with static glibc and with musl for `x86_64`, `i686`, `aarch64`, `armv7` hard float,
  `arm` soft float, `riscv64gc`, `powerpc64le` and `loongarch64`, plus `x86_64-pc-windows-gnu`.
  A Linux binary must have neither an interpreter nor needed libraries and the Windows one must
  import only system libraries, otherwise the build fails. Every binary is renamed to
  `<package>-<version>-<target>` with underscores instead of dots in the version and packed into
  `rust/target/assets/<name>.txz`, the Windows one into `<name>.7z`:

  ```bash
  ./rust.sh
  ```

- `ovepn-hook` handles OpenVPN pushes and re-reads `/etc/openvpn/ovepn.toml` on every reconnect, the file is the `WRT_OVEPN_HOOK` secret as is, declared in `green-wise/OpenWRT/<name>.sh` like other `WRT_OVEPN_*` secrets; without it the file is absent and the hook works with the empty config:

  ```toml
  # networks always routed into the tunnel: address, address/prefix or address/netmask
  nets = ["10.20.30.40", "10.20.31.0/24", "10.20.32.0/255.255.255.0"]
  # pushed public networks: "none" to ignore all or "/N" to accept up to /N
  public = "/30"
  # extra domains resolved by pushed dns servers
  domains = ["corp.example"]
  ```

- the `rust` workflow runs `rust.sh`, which replaces the placeholder version only in GitHub
  Actions. Pull requests changing `rust/` or `rust.sh` build `<last>-dev.<run>.<attempt>`, where
  `<last>` is the version of `git describe --abbrev=0 --match '<package>/*'` or `0.0.0` without
  such tag (`.dev.` instead of `-dev.` when it already has `-`), and upload binaries into the
  shared `v999` draft of this repository, replacing assets with the same name. A pushed annotated
  `<package>/<version>` tag builds only that package with the version from `git describe` and
  publishes the release:

  ```bash
  git checkout master && git pull; TAG4REL='ovepn-hook/0.1.0'
  git tag -fm $(git branch --sho) ${TAG4REL} && git push --force origin ${TAG4REL}
  ```

## Clean eMMC install steps

- flash sdcard image `dd if=bpi_r3-rel${VER}-name-*-install.img of=/dev/sda`

- boot from sdcard with H-H-H-H switchers

- install to NAND from the boot menu

- boot from NAND with H-L-H-L switchers

- install to eMMC from the boot menu

- boot from eMMC with L-H-H-L switchers

- perform `sysupgrade` with `bpi_r3-rel${VER}-name-*-sysupgrade.itb`
