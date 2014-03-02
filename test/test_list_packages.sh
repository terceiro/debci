. $(dirname $0)/test_helper.sh

export debci_config_dir="$TMPDIR"

setUp() {
  rm -rf $TMPDIR/*
}

tearDown() {
  rm -rf $TMPDIR/*
}

test_with_whitelist() {
  echo "pkg1" > $TMPDIR/whitelist
  assertEquals "pkg1" "$(./scripts/list-dep8-packages)"
}

test_with_blacklist() {
  echo "pkg1" >> $TMPDIR/whitelist
  echo "pkg2" >> $TMPDIR/whitelist
  echo "pkg3" >> $TMPDIR/whitelist

  echo "pkg2" > $TMPDIR/blacklist

  ./scripts/list-dep8-packages > $TMPDIR/pkgs
  assertTrue 'pkg1 should be listed' "grep -q pkg1 $TMPDIR/pkgs"
  assertFalse "package pkg2 is blacklisted, should not be listed" "grep -q pkg2 $TMPDIR/pkgs"
  assertTrue 'pkg3 should be listed' "grep -q pkg3 $TMPDIR/pkgs"
}

. shunit2
