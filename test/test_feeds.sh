#!/bin/sh

base=$(dirname $0)/..
. $base/test/test_helper.sh

test_no_new_is_good_news() {
  result_pass debci test --quiet foobar
  result_pass debci test --quiet foobar
  debci update --quiet

  news_count=$(grep -c "<title>foobar.*ED" "$debci_data_basedir/feeds/f/foobar.xml")
  assertEquals 0 "$news_count"
}

# XXX the tests below are inherently racy; every pair of tests will most
# probably get the same timestamp as our resolution is 1 second; but since the
# behavior with regards to status items being being newsworthy is properly unit
# tested in the Ruby code, either FAIL/PASS or PASS/FAIL, in any order, is good
# enough here.

test_notify_on_fail() {
  result_pass debci test --quiet foobar
  result_fail debci test --quiet foobar
  debci update --quiet

  news_count=$(grep -c '<title>foobar.*ED' "$debci_data_basedir/feeds/f/foobar.xml")
  assertEquals 1 "$news_count"
}

test_system_wide_feed() {
  result_pass debci test --quiet foobar
  result_fail debci test --quiet foobar
  result_fail debci test --quiet bazqux
  result_pass debci test --quiet bazqux
  debci update --quiet

  foobar_news=$(grep -c '<title>foobar.*ED' "$debci_data_basedir/feeds/all-packages.xml")
  assertEquals 1 "$foobar_news"

  bazqux_news=$(grep -c '<title>bazqux.*ED' "$debci_data_basedir/feeds/all-packages.xml")
  assertEquals 1 "$bazqux_news"
}

. shunit2
