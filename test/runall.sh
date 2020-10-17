set -eu

. $(dirname $0)/dep8_helper.sh

testdir=$(dirname $0)
if [ $# -eq 0 ]; then
  set -- $(find $testdir -name 'test_*.sh' -and -not -name 'test_helper.sh')
fi

report() {
  local color="$1"
  local message="$2"
  if test -t 1; then
    printf "\033[0;${color};40m%s\033[m\n" "$message"
  else
    echo "$message"
  fi
}

start_time=$(date +%s)
failed=""
for test_script in $@; do
  tmpdir=$(mktemp -d)
  echo "$test_script"
  start_test=$(date +%s)
  (
    set +e
    sh $test_script
    echo "$?" > $tmpdir/.exit_status
  ) 2>&1 | sed -e 's/^/    /; /warning: Insecure world writable dir/d'
  end_test=$(date +%s)
  test_duration=$(($end_test - $start_test))
  rc=$(cat $tmpdir/.exit_status)
  if [ "$rc" -eq 0 ]; then
    report 32 "☑ $test_script passed all tests in ${test_duration}s"
  else
    failed="$failed $test_script"
    report 31 "☐ $test_script failed at least one test in ${test_duration}s"
  fi
  rm -rf "$tmpdir"
done
end_time=$(date +%s)
duration=$(($end_time - $start_time))
echo
echo "Finished in ${duration} seconds"
for t in $failed; do
  echo "Failed: $t"
done
test -z "$failed"
