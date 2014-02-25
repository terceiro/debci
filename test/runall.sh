set -e

base=$(readlink -f $(dirname $0)/..)

report() {
  local color="$1"
  local test_name="$2"
  local result="$3"
  if test -t 1; then
    printf "\033[38;5;${color}m%-40s %s\033[m\n" "$test_name" "$result"
  else
    printf "%-40s %s\n" "$test_name" "$result"
  fi
}

tests=0
passed=0
failed=0
for test_script in $(find 'test/' -type f -executable); do
  tests=$(($tests + 1))
  test_name=$(basename $test_script)
  if $test_script; then
    report 2 $test_name PASS
    passed=$(($passed + 1))
  else
    report 1 $test_name FAIL
    failed=$(($failed + 1))
  fi
done

echo
echo "$tests tests, $passed passed, $failed failed"
exit $failed
