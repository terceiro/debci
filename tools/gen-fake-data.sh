#!/bin/sh

set -eu

./tools/init-dev.sh

get_packages() {
  if [ $# -eq 0 ]; then
    set -- $(shuf --head-count=50 config/whitelist)
  fi
  echo "$@"
}

configdir=`./bin/debci config --values-only config_dir`

for suite in $(./bin/debci config --values-only suite_list); do
  for arch in $(./bin/debci config --values-only arch_list); do
    get_packages "$@" \
      | xargs ./bin/debci enqueue --arch="$arch" --suite="$suite"
  done
done
