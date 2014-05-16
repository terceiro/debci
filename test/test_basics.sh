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

test_packages_without_runs_yet() {
  result_pass debci batch
  find $debci_data_basedir -type d -name rake | xargs rm -rf
  debci generate-index
  find $debci_data_basedir -name packages.json | xargs cat | json_pp -f json -t json > /dev/null
  assertEquals 0 $?
}

. shunit2
