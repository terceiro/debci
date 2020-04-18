#!/bin/sh

. $(dirname $0)/test_helper.sh

test_almost_empty_data_dir() {
  echo "1" > "$debci_data_basedir/schema_version"
  rc=0
  debci html update || rc=$?
  assertEquals 0 $rc
}

. shunit2
