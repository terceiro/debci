set -eu

# DEP-8/autopkgtest support: only use local binaries when not running under a
# DEP-8 runner, when you are supposed to test the installed package
if [ -z "${ADTTMP:-}" ]; then
  base=$(readlink -f $(dirname $0)/..)
  export PATH="$base/bin:${PATH}"
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

testdir=$(dirname $0)

tests=0
passed=0
failed=0
cd "$testdir"
for test_script in $(find . -type f -executable); do
  tests=$(($tests + 1))
  tmpdir=$(mktemp -d)
  echo "$test_script"
  (
    set +e
    $test_script
    echo "$?" > $tmpdir/.exit_status
  ) | sed -e 's/^/    /'
  rc=$(cat $tmpdir/.exit_status)
  if [ "$rc" -eq 0 ]; then
    passed=$(($passed + 1))
    report 32 "☑ $test_script passed all tests"
  else
    failed=$(($failed + 1))
    report 31 "☐ $test_script failed at least one test"
  fi
  rm -rf "$tmpdir"
done

exit $failed
