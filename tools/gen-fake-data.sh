#!/bin/sh

set -eu

configdir=$(dirname $0)/../config

if [ ! -f $configdir/whitelist ]; then
  for pkg in ruby-defaults rake ruby-ffi gem2deb; do
    echo "$pkg"
  done > $configdir/whitelist
fi

for arch in $(./bin/debci config --values-only arch_list); do
  for pkg in $(cat $configdir/whitelist); do
    ./bin/debci enqueue --arch "$arch" "$pkg"
  done
done
