#!/bin/sh

. $(dirname $0)/test_helper.sh

test_setkey_and_auth() {
  key=$(debci api setkey apiuser)
  debci api auth "$key" > /dev/null
  rc=$?
  assertEquals 0 "$rc"
}

test_invalid_key() {
  debci api auth "00000000-0000-0000-0000-000000000000" 2> /dev/null
  rc=$?
  assertNotEquals 0 "$rc"
}

. shunit2
