set -u

. $(dirname $0)/test_helper.sh


test_fails_gracefully_on_uneexisting_directory() {
  output=$(debci test --run-id 1 --backend null foo/bar 2>&1)
  assertFalse "[ -d $debci_data_basedir/autopkgtest-incoming/unstable/${debci_arch}/t/test/1 ]"
}

test_fails_gracefully_on_existing_directory_that_is_not_a_package() {
  mkdir -p $__tmpdir/test
  output=$(cd $__tmpdir && debci test --run-id 1 --backend null test/)
  assertEquals "" "$output"
}

test_package="${0%/*}/test-package-large-logs"
test_truncates_large_logs() {
  (cd $test_package && debci test --run-id 1 --backend null .) # >/dev/null 2>&1)
  log="$debci_data_basedir/autopkgtest-incoming/unstable/${debci_arch}/t/test-package-large-logs/1/log"
  assertTrue "[ -f ${log}.gz ]"
  gunzip "${log}.gz"
  size=$(stat --format=%s "${log}")
  upper_limit=$((21*1024*1024))
  assertTrue "log is smaller than 21MB" "[ $size -lt $upper_limit ]"
}

. shunit2
