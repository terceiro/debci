set -e

report() {
  local color="$1"
  local message="$2"
  if test -t 1; then
    printf "\033[0;${color};40m%s\033[m\n" "$message"
  else
    echo "$message"
  fi
}

tests=0
passed=0
failed=0
for test_script in $(find 'test/' -type f -executable); do
  tests=$(($tests + 1))
  test_name=$(basename $test_script)
  tmpdir=$(mktemp -d)
  if $test_script; then
    report 32 "☑ $test_name passed all tests"
    passed=$(($passed + 1))
  else
    report 31 "☐ $test_name failed at least one test"
    failed=$(($failed + 1))
  fi
  rm -rf "$tmpdir"
done

exit $failed
