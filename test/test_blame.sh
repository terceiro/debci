#!/bin/sh

. $(dirname $0)/test_helper.sh


export debci_backend='fake'
export debci_data_basedir="$TMPDIR/data"

setUp() {
  mkdir -p $TMPDIR/data
}

tearDown() {
  rm -rf $TMPDIR/data
}


set -u

__day=0
process() {
  pkg="$1"
  result="$2"
  dependencies="$3"
  mkdir -p $TMPDIR/data
  DEBCI_FAKE_DEPS="$dependencies" \
    DEBCI_FAKE_RESULT="$result" \
    faketime +${__day}days ./scripts/process-package "$pkg" --quiet
  __day=$(($__day + 1))
}

test_package_that_never_passed_a_test_cant_blame() {
  process foobar fail 'foo 1.2.3'
  process foobar fail 'foo 1.2.4'
  assertEquals '' "$(debci-status --field blame foobar)"
}

test_failing_test_blames_dependencies() {
  process foobar pass 'foo 1.2.3|bar 2.3.4'
  process foobar fail 'foo 1.3.1|bar 2.3.4'
  blame="$(debci-status --field blame foobar)"
  assertEquals 'foo 1.3.1' "$blame"
}

test_new_dependency_of_already_failing_package_is_not_blamed() {
  process foobar pass 'foo 1.2.3'
  process foobar fail 'foo 1.2.4'
  process foobar fail 'foo 1.2.4|bar 4.5.6'
  assertEquals 'foo 1.2.4' "$(debci-status --field blame foobar)"
}

test_passing_the_test_resets_the_blame() {
  process foobar pass 'foo 1.2.3'
  process foobar fail 'foo 1.2.4'
  process foobar pass 'foo 1.2.5'
  assertEquals '' "$(debci-status --field blame foobar)"
}

test_blame_updated_dependency() {
  process foobar pass 'foo 1.2.3'
  process foobar fail 'foo 1.2.4'
  process foobar fail 'foo 1.2.5'
  assertEquals 'foo 1.2.5' "$(debci-status --field blame foobar)"
}

. shunit2
