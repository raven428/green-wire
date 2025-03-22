#!/usr/bin/env bash
set -ueo pipefail
[[ -d 'green-wise' ]] ||
  /usr/bin/env git clone "https://${GITHUB_TOKEN}@github.com/raven428/green-wise.git"
JSON_LIST='['
for conf_file in green-wise/OpenWRT/*.sh; do
  file_base="$(basename "${conf_file%.*}")"
  JSON_LIST="${JSON_LIST}\"${file_base}\","
done
export JSON_LIST="${JSON_LIST%,}]"
echo "${JSON_LIST}"
