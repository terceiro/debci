#!/bin/sh
set -u

. $(dirname $0)/test_helper.sh

test_trigger() {
  result_pass start_worker
  debci enqueue --trigger=foo/1.0 bar
  wait_for_results bar

  artifacts=$(find $debci_data_basedir -name artifacts.tar.gz)
  mkdir $__tmpdir/extract
  tar xaf "$artifacts" -C $__tmpdir/extract
  trigger=$(find $__tmpdir/extract -name trigger)
  assertEquals "foo%2F1.0" "$(cat "$trigger")"
}

test_pin_packages() {
  result_pass start_worker
  debci enqueue --pin-packages=unstable=debci bar
  wait_for_results bar

  log=$(find $debci_data_basedir -name log.gz)
  assertTrue "zgrep '.--add-apt-release=unstable' $log"
  assertTrue "zgrep '.--pin-packages=unstable=debci' $log"
}

. shunit2
