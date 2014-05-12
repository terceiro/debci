#!/bin/sh

. $(dirname $0)/test_helper.sh

test_everything_passes() {
  result_pass debci batch
  assertEquals "pass" "$(debci status -l | awk '{print($2)}' | uniq)"
}

test_everything_fails() {
  result_fail debci batch
  assertEquals 'fail' "$(debci status -l | awk '{print($2)}' | uniq)"
}

. shunit2
