#!/usr/bin/env bash
set -ueo pipefail
VERSION_ID="23.05.5"
OPENWRT_ARCH="aarch64_cortex-a53"
OPENWRT_BOARD="mediatek/filogic"
REPO_URL='rsync://rsync.openwrt.org'
REPO_DIR="downloads/releases/${VERSION_ID}"
REPO_LOCAL='/home/a/arc/unix/linux/openwrt'
REPO_CORE="${REPO_DIR}/targets/${OPENWRT_BOARD}"
REPO_PKGS="${REPO_DIR}/packages/${OPENWRT_ARCH}"

for CUR_DIR in "${REPO_CORE}" "${REPO_PKGS}"; do
  mkdir -vp "${REPO_LOCAL}/${CUR_DIR}"
  rsync -cvaHAX \
    --force --delete --info=progress2 \
    "${REPO_URL}/${CUR_DIR}/" "${REPO_LOCAL}/${CUR_DIR}/"
done
