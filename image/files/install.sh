#!/usr/bin/env bash
set -ueo pipefail
patch -p0 </builder/files/filogic.diff
rm -rfv /builder/files
