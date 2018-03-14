#!/bin/sh

set -eu

configdir=`./bin/debci config --values-only config_dir`

if [ ! -f $configdir/whitelist ]; then
  for pkg in ruby-defaults rubygems-integration autodep8 pristine-tar; do
    echo "$pkg"
  done > $configdir/whitelist
fi

if [ ! -f $configdir/conf.d/dev.conf ]; then
  echo "debci_arch_list='amd64 arm64'" > $configdir/conf.d/dev.conf
  echo "debci_suite_list='unstable testing stable'" >> $configdir/conf.d/dev.conf
  echo "debci_backend=fake" >> $configdir/conf.d/dev.conf
fi

tail -n 1000 config/whitelist config/conf.d/*.conf
