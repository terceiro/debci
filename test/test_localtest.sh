#!/bin/sh

. $(dirname $0)/test_helper.sh

fake_package="${0%/*}/fake-package"

test_basic() {
  rc=0
  output=$(debci localtest -b null "$fake_package" 2>&1) || rc=$?
  assertEquals 0 "$rc"
  if [ "$rc" -ne 0 ]; then echo "$output"; fi
}

. shunit2
