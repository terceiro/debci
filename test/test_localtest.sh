#!/bin/sh

. $(dirname $0)/test_helper.sh

fake_package="${0%/*}/fake-package"

test_basic() {
  assertTrue "debci localtest -b null $fake_package"
}

. shunit2
