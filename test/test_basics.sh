#!/bin/sh

. $(dirname $0)/test_helper.sh

test_everything_passes() {
  result_pass start_worker
  debci batch
  wait_for_results
  status=$(debci status -l)
  assertEquals "pass" "$(echo "$status" | awk '{print($2)}' | uniq)"

  # check validity of debci-status format
  echo "$status" | grep -q '^ruby *pass$' || fail "invalid format:\n$status"
  echo "$status" | grep -q '^rake *pass$' || fail "invalid format:\n$status"

  history_file="${debci_data_basedir}/status/unstable/${debci_arch}/history.json"

  history_entries=$(ruby -rjson -e "puts JSON.load(File.open('$history_file')).size")
  assertTrue "History entries in $history_file:  $history_entries!" "[ $history_entries -gt 0 ]"
}

test_everything_fails() {
  result_fail start_worker
  debci batch
  wait_for_results
  status=$(debci status -l)
  assertEquals "fail" "$(echo "$status" | awk '{print($2)}' | uniq)"

  # check validity of debci-status format
  echo "$status" | grep -q '^ruby *fail$' || fail "invalid format:\n$status"
  echo "$status" | grep -q '^rake *fail$' || fail "invalid format:\n$status"
}

test_packages_without_runs_yet() {
  result_pass start_worker
  debci batch
  wait_for_results
  find $debci_data_basedir -type d -name rake | xargs rm -rf
  debci update
  find $debci_data_basedir -path '*data/status*' -name packages.json | xargs cat | json_pp -f json -t json > /dev/null
  assertEquals 0 $?
}

test_status_no_runs() {
  echo 'mypkg' > $debci_config_dir/seed_list
  status="$(debci status -l)"
  (echo "$status" | grep -q '^mypkg\s*unknown$') || fail "invalid status: $status"
}

test_single_package() {
  echo "mypkg" > $debci_config_dir/seed_list
  result_pass start_worker
  debci batch
  wait_for_results
  assertEquals "mypkg pass" "$(debci status -l)"
}

# batch skips a package after it previously succeeded and there is no
# dependency change
test_batch_skip_after_result() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/seed_list
  result_pass start_worker
  debci batch
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 1 $num_runs

  debci batch
  start_worker
  # XXX it's unfortunate that we need to wait a bit here, but for now there is
  # no way to tap in the enqueueing process to make sure nothing is scheduled.
  timeout 3s "$testbin"/wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 1 $num_runs
}

# batch re-runs a package after it previously tmpfailed
test_batch_rerun_after_tmpfail() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/seed_list
  result_tmpfail start_worker
  debci batch
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 1 $num_runs

  result_pass start_worker
  debci batch
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 2 $num_runs
}

# batch re-runs a package on changed dependencies
test_batch_rerun_dep_change() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/seed_list
  result_pass start_worker
  debci batch
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 1 $num_runs

  export DEBCI_FAKE_DEPS="foo 1.2.4"
  result_pass start_worker
  debci batch
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 2 $num_runs
}

# batch runs a package without changes with --force
test_batch_force() {
  export DEBCI_FAKE_DEPS="foo 1.2.3"
  echo "mypkg" > $debci_config_dir/seed_list
  result_pass start_worker
  debci batch
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 1 $num_runs

  result_pass start_worker
  debci batch --force
  wait_for_results
  num_runs=$(grep -c '"package":' $(status_dir_for_package mypkg)/history.json)
  assertEquals 2 $num_runs
}

test_batch_wont_enqueue_twice() {
  start_rabbitmq_server
  echo "mypkg" > $debci_config_dir/seed_list
  debci batch --force
  debci batch --force

  num_requests=$(clean_queue)
  assertEquals 1 $num_requests
}

test_status_for_all_packages() {
  result_pass start_worker
  debci batch
  wait_for_results
  local status_file="$debci_data_basedir/status/unstable/$debci_arch/packages.json"
  assertTrue 'ruby-ffi present in status file' "grep ruby-ffi $status_file"
  assertTrue 'rubygems-integration present in status file' "grep rubygems-integration $status_file"
}

. shunit2
