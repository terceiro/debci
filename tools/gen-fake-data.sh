#!/bin/sh

set -eu

runs=${1:-15}

configdir=$(dirname $0)/../config

if [ ! -f $configdir/whitelist ]; then
  for pkg in ruby-defaults rake ruby-ffi gem2deb; do
    echo "$pkg"
  done > $configdir/whitelist
fi

debci_status_dir=$(sh -c '. lib/environment.sh ; echo $debci_status_dir')

for n in $(seq $runs -1 1); do
  faketime -${n}days ./bin/debci batch --backend fake -j 2 "$@"
  # fake the duration with a "random" number of seconds up to 10h
  status_file="${debci_status_dir}/status.json"
  duration=$(( $(sha256sum "$status_file" | sed ' s/[^0-9]//g; s/^0\+//; s/^\([0-9]\{0,6\}\).*/\1/g;') % 36000 ))
  sed --follow-symlinks --in-place -e "s/\"duration\": [0-9]\+/\"duration\": $duration/" "$status_file"
done
