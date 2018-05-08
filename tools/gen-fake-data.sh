#!/bin/sh

set -eu

./tools/init-dev.sh

configdir=`./bin/debci config --values-only config_dir`

for suite in $(./bin/debci config --values-only suite_list); do
  for arch in $(./bin/debci config --values-only arch_list); do
    shuf --head-count=50 config/whitelist \
      | xargs ./bin/debci enqueue --arch="$arch" --suite="$suite"
  done
done
