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

test_system_wide_feed() {
  result_pass debci-test --quiet foobar
  result_fail debci-test --quiet foobar
  result_fail debci-test --quiet bazqux
  result_pass debci-test --quiet bazqux
  debci-generate-index --quiet --duration 0

  foobar_news=$(grep -c 'foobar tests' "$debci_data_basedir/feeds/all-packages.xml")
  assertEquals 1 "$foobar_news"

  bazqux_news=$(grep -c 'foobar tests' "$debci_data_basedir/feeds/all-packages.xml")
  assertEquals 1 "$bazqux_news"
}

. shunit2
