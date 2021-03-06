base=$(dirname $0)
. $base/test_helper.sh

test_with_seed_list() {
  echo "pkg1" > $debci_config_dir/seed_list
  list="$(debci list-packages)"
  assertEquals "pkg1" "$list"
}

test_with_reject_list() {
  echo "pkg1" >> $debci_config_dir/seed_list
  echo "pkg2" >> $debci_config_dir/seed_list
  echo "pkg3" >> $debci_config_dir/seed_list

  echo "pkg2" > $debci_config_dir/reject_list

  debci list-packages > $debci_config_dir/pkgs
  assertTrue 'pkg1 should be listed' "grep -q pkg1 $debci_config_dir/pkgs"
  assertFalse "package pkg2 is rejectlisted, should not be listed" "grep -q pkg2 $debci_config_dir/pkgs"
  assertTrue 'pkg3 should be listed' "grep -q pkg3 $debci_config_dir/pkgs"
}

test_executable_seed_list() {
  echo '#!/bin/sh' > $debci_config_dir/seed_list
  echo 'printf "pkg1\n"' >> $debci_config_dir/seed_list
  echo 'printf "pkg2\n"' >> $debci_config_dir/seed_list
  chmod +x $debci_config_dir/seed_list

  assertEquals "pkg1 pkg2" "$(debci list-packages | xargs echo)"
}

test_remove_duplicates() {
  echo pkg1 > $debci_config_dir/seed_list
  echo pkg1 >> $debci_config_dir/seed_list
  assertEquals "pkg1" "$(debci list-packages)"
}

. shunit2
