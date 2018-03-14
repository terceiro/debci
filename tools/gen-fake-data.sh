#!/bin/sh

set -eu

./tools/init-dev.sh

configdir=`./bin/debci config --values-only config_dir`

for suite in $(./bin/debci config --values-only suite_list); do
  for arch in $(./bin/debci config --values-only arch_list); do
    for pkg in $(cat $configdir/whitelist); do
      ./bin/debci enqueue --arch="$arch" --suite="$suite" "$pkg"
    done
  done
done
