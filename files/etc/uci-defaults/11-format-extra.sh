#!/usr/bin/env bash
set -u
non_formatted_extra="$(
  /usr/bin/env lsblk -i -o path,partlabel,fstype -J |
    /usr/bin/env jq -r '.blockdevices[] |
    select(.partlabel == "extra" and .fstype == null) |
    .path'
)"
move_home=0
if [[ ${non_formatted_extra:-none} == none ]]; then
  echo 'extra filesystem already formatted or not exist' | tee /dev/kmsg
else
  echo "extra filesystem in [${non_formatted_extra}] has not been formatted yet" |
    tee /dev/kmsg
  /usr/bin/env mkfs.f2fs -l extra "${non_formatted_extra}" | tee /dev/kmsg
  move_home=1
fi
uci_record="$(
  /usr/bin/env uci show fstab |
    /usr/bin/env fgrep "label='extra'" |
    sed -E 's/.+\[(.+)\].+/\1/'
)" || /usr/bin/env true
if [[ ${uci_record:-none} != none ]]; then
  echo "removing [${uci_record}] uci record" | tee /dev/kmsg
  /usr/bin/env uci delete "fstab.@mount[${uci_record}]"
fi
uci_record="$(/usr/bin/env uci add fstab mount)"
echo "adding [${uci_record}] uci record" | tee /dev/kmsg
/usr/bin/env uci set "fstab.${uci_record}.target"='/extra'
/usr/bin/env uci set "fstab.${uci_record}.label"='extra'
/usr/bin/env uci set "fstab.${uci_record}.enable"='1'
uci_record="$(/usr/bin/env uci add fstab mount)"
/usr/bin/env mkdir -vp /nvme | tee /dev/kmsg
/usr/bin/env uci set "fstab.${uci_record}.target"='/nvme'
/usr/bin/env uci set "fstab.${uci_record}.label"='nvme'
/usr/bin/env uci set "fstab.${uci_record}.enable"='1'
/usr/bin/env uci commit
/usr/bin/env block mount
if [[ ${move_home} == 1 ]]; then
  /usr/bin/env rm -rfv /extra/home 2>&1 | tee /dev/kmsg
  /usr/bin/env mkdir -vp /extra/{home,opt} 2>&1 | tee /dev/kmsg
  /usr/bin/env mv -vf /root /extra/home 2>&1 | tee /dev/kmsg
  /usr/bin/env mv -vf /extra/home/root/dot-git \
    /extra/home/root/.git 2>&1 | tee /dev/kmsg
else
  echo 'extra partition format isn'\''t happened, skipped home moving' | tee /dev/kmsg
fi
/usr/bin/env rm -rfv /opt /root 2>&1 | tee /dev/kmsg
/usr/bin/env ln -sfv /extra/opt /opt 2>&1 | tee /dev/kmsg
/usr/bin/env ln -sfv /extra/home/root /root 2>&1 | tee /dev/kmsg
exit 0
