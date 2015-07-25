#!/bin/sh

. $(dirname $0)/test_helper.sh

test_read_debci_conf() {
  echo "debci_foo=bar" > "${debci_config_dir}/debci.conf"
  assertEquals 'foo=bar' $(debci config foo)
}

test_read_conf_d() {
  mkdir -p "${debci_config_dir}/conf.d"
  echo "debci_foo=bar" > "${debci_config_dir}/conf.d/foo.conf"
  assertEquals 'foo=bar' $(debci config foo)
}

. shunit2
