#!/bin/sh

set -eu

configdir=$(dirname $0)/../config

if [ ! -f $configdir/whitelist ]; then
  for pkg in ruby-defaults rubygems-integration autodep8 pristine-tar; do
    echo "$pkg"
  done > $configdir/whitelist
fi

if [ ! -f $configdir/conf.d/dev.conf ]; then
  echo "debci_arch_list='amd64 arm64'" > $configdir/conf.d/dev.conf
  echo "debci_suite_list='unstable stable'" >> $configdir/conf.d/dev.conf
  echo "debci_backend=fake" >> $configdir/conf.d/dev.conf
fi

for suite in $(./bin/debci config --values-only suite_list); do
  for arch in $(./bin/debci config --values-only arch_list); do
    for pkg in $(cat $configdir/whitelist); do
      ./bin/debci enqueue --arch="$arch" --suite="$suite" "$pkg"
    done
  done
done
