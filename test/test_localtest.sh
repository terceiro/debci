#!/bin/sh

. $(dirname $0)/test_helper.sh

test_basic() {
  assertTrue 'debci localtest -b null test/fake-package'
}

. shunit2
