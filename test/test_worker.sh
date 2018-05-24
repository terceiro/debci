#!/bin/sh
set -u

. $(dirname $0)/test_helper.sh

# let's mess with a seperate queue just for this test
export debci_amqp_queue="${debci_amqp_queue}-stress"

request() {
  debci enqueue $1
}

settle_processes() {
  local timeout=600
  while [ $timeout -gt 0 ]; do
    PS=$(ps hx -o pid,comm|egrep "(debci|test-package|autopkgtest|amqp-consume)"|sort -u)
    [ -n "$PS" ] || break
    timeout=$((timeout - 1))
    sleep 0.1
  done
  assertEquals "unexpected leftover processes" "" "$PS"
}

run_mypkg() {
  start_worker
  debci job declare-queue
  start_collector
  request mypkg
  # give it some time to process requests; make it large for slow systems
  sleep 2
  if [ "${DEBCI_FAKE_KILLPARENT:-x}" = "amqp-consume" ]; then
    [ ! -e /proc/$TEST_WORKER_PID ] || fail "test worker unexpectedly survived"
  else
    [ -e /proc/$TEST_WORKER_PID ] || fail "test worker unexpectedly died"
  fi
  stop_worker
  stop_collector
  settle_processes
  RESULT_DIR=$(autopkgtest_incoming_dir_for_package mypkg)
}

test_no_crash_success() {
  unset DEBCI_FAKE_KILLPARENT
  result_pass run_mypkg
  assertEquals "has leftover requests" "0" $(clean_queue)
  # we should have one log
  assertEquals 1 "$(ls $RESULT_DIR/*/log.gz | wc -l)"
  assertEquals 1 "$(ls $RESULT_DIR/*/exitcode | wc -l)"
}

test_no_crash_fail() {
  unset DEBCI_FAKE_KILLPARENT
  result_fail run_mypkg
  assertEquals "has leftover requests" "0" "$(clean_queue)"
  # we should have one log
  assertEquals 1 "$(ls $RESULT_DIR/*/log.gz | wc -l)"
  assertEquals 1 "$(ls $RESULT_DIR/*/exitcode | wc -l)"
}

test_no_crash_tmpfail() {
  unset DEBCI_FAKE_KILLPARENT
  result_tmpfail run_mypkg
  assertEquals "has leftover requests" "0" "$(clean_queue)"
  # we should have one log
  assertEquals 1 "$(ls $RESULT_DIR/*/log.gz | wc -l)"
  assertEquals 1 "$(ls $RESULT_DIR/*/exitcode | wc -l)"
}

test_crash_test_package() {
  export DEBCI_FAKE_KILLPARENT="test-package"
  result_pass run_mypkg
  assertEquals "aborted request got lost" "1" "$(clean_queue)"
  # there might be an incomplete logd dir, but not an exit code
  assertEquals 0 "$(ls $RESULT_DIR/*/exitcode 2>/dev/null| wc -l)"
}

test_crash_debci_test() {
  export DEBCI_FAKE_KILLPARENT="debci-test"
  result_pass run_mypkg
  assertEquals "aborted request got lost" "1" "$(clean_queue)"
  [ -e "$RESULT_DIR" ] && fail "has unexpected result dir"
}

test_crash_worker() {
  export DEBCI_FAKE_KILLPARENT="debci-worker"
  run_mypkg
  assertEquals "aborted request got lost" "1" "$(clean_queue)"
  # there should be no logs
  [ -e "$RESULT_DIR" ] && fail "has unexpected result dir"
}

# generate lots of test requests, start lots of workers, and then go around and
# crash two thirds of them; ensure that we get all results
NUM_REQUESTS=100
NUM_WORKERS=30
test_smoke() {
  unset DEBCI_FAKE_KILLPARENT

  start_rabbitmq_server
  debci job declare-queue

  local WORKERS=''
  for i in `seq $NUM_WORKERS`; do
    debci worker &
    WORKERS="$WORKERS $!"
  done
  sleep 0.3

  for i in `seq $NUM_REQUESTS`; do
    request pkg$i
  done

  local i=0
  for w in $WORKERS; do
    i=$(( (i + 1) % 3))
    if [ $i -ne 0 ]; then
      kill -kill $w
    fi
  done

  start_collector

  # wait until all requests have been consumed; unfortunately we have no shell
  # tool (except rabbitmqctl list_queues, which needs root) to show the queue
  # status, so we poll for all packages being handled
  local timeout=600
  local completed=0
  while [ $completed -lt $NUM_REQUESTS ] && [ $timeout -gt 0 ]; do
    sleep 0.1
    timeout=$((timeout - 1))
    while [ $(find $debci_data_basedir/autopkgtest-incoming/unstable/$debci_arch/p/pkg$(($completed + 1)) -name duration 2>/dev/null | wc -l) -gt 0 ]; do
      completed=$(($completed + 1))
    done
  done
  if [ $timeout -eq 0 ]; then
    echo "TIMED OUT"
  fi
  assertEquals "has leftover requests" "0" "$(clean_queue)"

  # clean up the remaining ones
  for w in $WORKERS; do
    kill $w 2>/dev/null && wait $w || true
  done
  stop_collector
  settle_processes

  # some tests get restarted, so we expect one or two logs
  for i in `seq $NUM_REQUESTS`; do
    local d=$(autopkgtest_incoming_dir_for_package pkg$i)
    nlogs=$(ls $d/*/log.gz | wc -l)
    nexit=$(ls $d/*/exitcode | wc -l)
    assertTrue "one or two logs for pkg$i" "[ $nlogs -eq 1 -o $nlogs -eq 2 ]"
    assertTrue "one or two complete result dirs for pkg$i" "[ $nexit -eq 1 -o $nexit -eq 2 ]"
  done
}

. shunit2
