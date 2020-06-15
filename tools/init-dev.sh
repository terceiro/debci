#!/bin/sh

set -eu

configdir=`./bin/debci config --values-only config_dir`

WHITELIST='autodep8
pinpoint
python-whitenoise
ruby-defaults
rubygems-integration
vim-addon-manager'

if [ ! -f $configdir/whitelist ]; then
  echo "$WHITELIST" > "$configdir/whitelist"
  tail -n 1000 config/whitelist config/conf.d/*.conf || :
  echo
fi

if [ ! -f $configdir/conf.d/dev.conf ]; then
  echo "debci_arch_list='amd64 arm64'" > $configdir/conf.d/dev.conf
  echo "debci_suite_list='unstable testing'" >> $configdir/conf.d/dev.conf
  echo "debci_backend=fake" >> $configdir/conf.d/dev.conf
fi

./bin/debci migrate
