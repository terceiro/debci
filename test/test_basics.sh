#!/bin/sh

. $(dirname $0)/test_helper.sh

test_everything_passes() {
  result_pass debci batch
  status=$(debci status -l)
  assertEquals "pass" "$(echo "$status" | awk '{print($2)}' | uniq)"

  # check validity of debci-status format
  echo "$status" | grep -q '^ruby *pass$' || fail "invalid format:\n$status"
  echo "$status" | grep -q '^rake *pass$' || fail "invalid format:\n$status"
}

test_everything_fails() {
  result_fail debci batch
  status=$(debci status -l)
  assertEquals "fail" "$(echo "$status" | awk '{print($2)}' | uniq)"

  # check validity of debci-status format
  echo "$status" | grep -q '^ruby *fail$' || fail "invalid format:\n$status"
  echo "$status" | grep -q '^rake *fail$' || fail "invalid format:\n$status"
}

test_packages_without_runs_yet() {
  result_pass debci batch
  find $debci_data_basedir -type d -name rake | xargs rm -rf
  debci generate-index
  find $debci_data_basedir -name packages.json | xargs cat | json_pp -f json -t json > /dev/null
  assertEquals 0 $?
}

test_single_package() {
  echo "mypkg" > $debci_config_dir/whitelist
  result_pass debci batch
  assertEquals "mypkg pass" "$(debci status -l)"
}

. shunit2
