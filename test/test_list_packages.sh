base=$(dirname $0)
. $base/test_helper.sh

test_with_whitelist() {
  echo "pkg1" > $debci_config_dir/whitelist
  list="$(debci list-packages)"
  assertEquals "pkg1" "$list"
}

test_with_blacklist() {
  echo "pkg1" >> $debci_config_dir/whitelist
  echo "pkg2" >> $debci_config_dir/whitelist
  echo "pkg3" >> $debci_config_dir/whitelist

  echo "pkg2" > $debci_config_dir/blacklist

  debci list-packages > $debci_config_dir/pkgs
  assertTrue 'pkg1 should be listed' "grep -q pkg1 $debci_config_dir/pkgs"
  assertFalse "package pkg2 is blacklisted, should not be listed" "grep -q pkg2 $debci_config_dir/pkgs"
  assertTrue 'pkg3 should be listed' "grep -q pkg3 $debci_config_dir/pkgs"
}

. shunit2
