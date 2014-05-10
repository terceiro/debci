#!/bin/sh

base=$(dirname $0)/..
. $base/test/test_helper.sh

test_no_new_is_good_news() {
  result_pass debci-test --quiet foobar
  result_pass debci-test --quiet foobar
  debci-generate-index --quiet --duration 0
  news_count=$(grep -c "foobar tests" "$debci_data_basedir/feeds/f/foobar.xml")
  assertEquals 0 "$news_count"
}

test_notify_on_fail() {
  result_pass debci-test --quiet foobar
  result_fail debci-test --quiet foobar
  debci-generate-index --quiet --duration 0
  news_count=$(grep -c 'foobar tests' "$debci_data_basedir/feeds/f/foobar.xml")
  assertEquals 1 "$news_count"
}

. shunit2
