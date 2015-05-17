#!/bin/sh

set -eu

n=${1:-15}

configdir=$(dirname $0)/../config

if [ ! -f $configdir/whitelist ]; then
  for pkg in ruby-defaults rake ruby-ffi gem2deb; do
    echo "$pkg"
  done > $configdir/whitelist
fi

while [ "$n" -gt 0 ]; do
  pkg=$(shuf $configdir/whitelist | head -1)
  ./bin/debci enqueue "$pkg"
  n=$(($n - 1))
done
