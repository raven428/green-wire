#!/usr/bin/env bash
# cspell:ignore gnueabi gnueabihf musleabi musleabihf objdump libc loong
# cspell:ignore readelf bcryptprimitives ntdll msvcrt lzma armel armhf INTERP RUSTFLAGS
set -ueo pipefail
# tests every rust/ package and builds static binaries for all targets one by one,
# outside GitHub Actions the version of Cargo.toml is kept as is
targets=(
  x86_64-unknown-linux-gnu x86_64-unknown-linux-musl
  i686-unknown-linux-gnu i686-unknown-linux-musl
  aarch64-unknown-linux-gnu aarch64-unknown-linux-musl
  armv7-unknown-linux-gnueabihf armv7-unknown-linux-musleabihf
  arm-unknown-linux-gnueabi arm-unknown-linux-musleabi
  riscv64gc-unknown-linux-gnu riscv64gc-unknown-linux-musl
  powerpc64le-unknown-linux-gnu powerpc64le-unknown-linux-musl
  loongarch64-unknown-linux-gnu loongarch64-unknown-linux-musl
  x86_64-pc-windows-gnu
)
# x86_64 linux targets use the default cc, musl ones link self-contained
declare -A linkers=(
  ['i686-unknown-linux-gnu']='i686-linux-gnu-gcc'
  ['i686-unknown-linux-musl']='rust-lld'
  ['aarch64-unknown-linux-gnu']='aarch64-linux-gnu-gcc'
  ['aarch64-unknown-linux-musl']='rust-lld'
  ['armv7-unknown-linux-gnueabihf']='arm-linux-gnueabihf-gcc'
  ['armv7-unknown-linux-musleabihf']='rust-lld'
  ['arm-unknown-linux-gnueabi']='arm-linux-gnueabi-gcc'
  ['arm-unknown-linux-musleabi']='rust-lld'
  ['riscv64gc-unknown-linux-gnu']='riscv64-linux-gnu-gcc'
  ['riscv64gc-unknown-linux-musl']='rust-lld'
  ['powerpc64le-unknown-linux-gnu']='powerpc64le-linux-gnu-gcc'
  ['powerpc64le-unknown-linux-musl']='rust-lld'
  ['loongarch64-unknown-linux-gnu']='loongarch64-linux-gnu-gcc'
  ['loongarch64-unknown-linux-musl']='rust-lld'
  ['x86_64-pc-windows-gnu']='x86_64-w64-mingw32-gcc'
)
apt_pkgs=(
  gcc-i686-linux-gnu libc6-dev-i386-cross
  gcc-aarch64-linux-gnu libc6-dev-arm64-cross
  gcc-arm-linux-gnueabihf libc6-dev-armhf-cross
  gcc-arm-linux-gnueabi libc6-dev-armel-cross
  gcc-riscv64-linux-gnu libc6-dev-riscv64-cross
  gcc-powerpc64le-linux-gnu libc6-dev-ppc64el-cross
  gcc-loongarch64-linux-gnu libc6-dev-loong64-cross
  gcc-mingw-w64-x86-64 7zip xz-utils
)
system_dlls='^(kernel32|ntdll|msvcrt|bcryptprimitives|api-ms-win-[a-z0-9-]+)\.dll$'
# checks that the binary requires nothing and packs it into target/assets
pack() {
  local target="$1" pkg="$2" ver="$3" bin name hdr dlls bad
  name="${pkg}-${ver//./_}-${target}"
  if [[ "${target}" == *-windows-* ]]; then
    bin="target/${target}/release/${pkg}.exe"
    dlls="$(x86_64-w64-mingw32-objdump -p "${bin}" |
      sed -En 's/^\s*DLL Name: (.+)$/\1/p')"
    bad="$(grep -viE "${system_dlls}" <<<"${dlls}" || true)"
    if [[ -n "${bad}" ]]; then
      echo "::error::[${bin}] imports non-system libraries: ${bad//$'\n'/ }"
      exit 1
    fi
    cp -v "${bin}" "target/assets/${name}.exe"
    (
      cd target/assets
      7z a -t7z -m0=lzma2 -mx=9 "${name}.7z" "${name}.exe"
      rm -f "${name}.exe"
    )
  else
    bin="target/${target}/release/${pkg}"
    hdr="$(readelf -lW -dW "${bin}")"
    if grep -qw -e INTERP -e NEEDED <<<"${hdr}"; then
      echo "::error::[${bin}] is not static:"
      grep -w -e INTERP -e NEEDED <<<"${hdr}"
      exit 1
    fi
    cp -v "${bin}" "target/assets/${name}"
    (
      cd target/assets
      tar --use-compress-program='xz -T0 -9e' -cf "${name}.txz" "${name}"
      rm -f "${name}"
    )
  fi
}
# runs in the container from rust/ with <package>:<version> arguments
inside() {
  local list=("$@") names target env_name flags rustflags p
  names=("${list[@]%%:*}")
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -qqy --no-install-recommends "${apt_pkgs[@]}"
  rustup target add "${targets[@]}"
  cargo fmt --all --check
  cargo test --locked "${names[@]/#/--package=}"
  rm -rf target/assets
  mkdir -p target/assets
  for target in "${targets[@]}"; do
    env_name="${target^^}"
    env_name="CARGO_TARGET_${env_name//-/_}"
    flags=()
    if [[ -v "linkers[${target}]" ]]; then
      flags+=("${env_name}_LINKER=${linkers[${target}]}")
    fi
    # some musl targets link dynamically by default
    rustflags='-C target-feature=+crt-static'
    # glibc cross packages lack static-pie start files for some targets
    if [[ "${target}" == *-linux-gnu* ]]; then
      rustflags+=' -C relocation-model=static'
    fi
    if [[ "${target}" == *-linux-* ]]; then
      flags+=("${env_name}_RUSTFLAGS=${rustflags}")
    fi
    env "${flags[@]}" cargo build --release --locked --target "${target}" \
      "${names[@]/#/--package=}"
    for p in "${list[@]}"; do
      pack "${target}" "${p%%:*}" "${p#*:}"
    done
  done
}
if [[ "${1:-}" == 'inside' ]]; then
  shift
  inside "$@"
  exit 0
fi
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
declare -A manifests=()
for f in rust/*/Cargo.toml; do
  manifests["$(sed -En '/^name = /{s/^name = "([^"]+)"$/\1/p;q}' "${f}")"]="${f}"
done
packages=()
# replaces the version of the package manifest and of its lock entry
set_version() {
  local pkg="$1" ver="$2"
  sed -Ei "0,/^version = \"[^\"]+\"$/s//version = \"${ver}\"/" "${manifests[${pkg}]}"
  sed -Ei "/^name = \"${pkg}\"$/{n;s/^version = \"[^\"]+\"$/version = \"${ver}\"/}" \
    rust/Cargo.lock
  packages+=("${pkg}:${ver}")
}
if [[ "${GITHUB_ACTIONS:-}" != 'true' ]]; then
  for pkg in "${!manifests[@]}"; do
    packages+=("${pkg}:$(sed -En '/^version = /{s/^version = "([^"]+)"$/\1/p;q}' \
      "${manifests[${pkg}]}")")
  done
elif [[ "${GITHUB_REF_TYPE:-}" == 'tag' ]]; then
  pkg="${GITHUB_REF_NAME%%/*}"
  if [[ ! -v "manifests[${pkg}]" ]]; then
    echo "::error::tag [${GITHUB_REF_NAME}] matches no package"
    exit 1
  fi
  if [[ "$(git cat-file -t "refs/tags/${GITHUB_REF_NAME}" 2>/dev/null)" != 'tag' ]]; then
    echo "::error::tag [${GITHUB_REF_NAME}] is not annotated"
    exit 1
  fi
  tag="$(git describe --match "${GITHUB_REF_NAME}" --exact-match)"
  set_version "${pkg}" "${tag#*/}"
else
  run="${GITHUB_RUN_NUMBER:?}.${GITHUB_RUN_ATTEMPT:?}"
  for pkg in "${!manifests[@]}"; do
    base='0.0.0'
    if tag="$(git describe --abbrev=0 --match "${pkg}/*" 2>/dev/null)"; then
      base="${tag#*/}"
    fi
    if [[ "${base}" == *-* ]]; then
      set_version "${pkg}" "${base}.dev.${run}"
    else
      set_version "${pkg}" "${base}-dev.${run}"
    fi
  done
fi
for p in "${packages[@]}"; do
  echo "package [${p%%:*}] version [${p#*:}]"
done
rust_ver="$(sed -En 's/^channel\s*=\s*"([^"]+)".*/\1/p' rust/rust-toolchain.toml)"
podman run --rm --network=host -u 0 -v "${PWD}:/src:rw" -w /src/rust \
  "mirror.gcr.io/library/rust:${rust_ver}-slim" bash /src/rust.sh inside "${packages[@]}"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "ASSETS=${PWD}/rust/target/assets" >>"${GITHUB_ENV}"
fi
