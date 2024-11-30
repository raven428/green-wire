#!/usr/bin/env bash
set -ueo pipefail
: "${TARGET_REGISTRY:=ghcr.io/raven428/container-images/openwrt-imagebuilder}"
: "${TAG:=mediatek-filogic-23_05_5}"
: "${IMAGE_VER:=000}"
/usr/bin/env docker build \
  --network host \
  -t "${TARGET_REGISTRY}/${TAG}:latest" \
  -t "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}" \
  image
if [[ "${GITHUB_REF:-refs/heads/master}" == "refs/heads/master" ]]; then
  /usr/bin/env docker push "${TARGET_REGISTRY}/${TAG}:latest"
  /usr/bin/env docker push "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}"
fi
