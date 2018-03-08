if ! which checkbashisms >/dev/null 2>&1; then
  echo "SKIP: checkbashisms not available"
  exit 0
fi
if ! which shellcheck >/dev/null 2>&1; then
  echo "SKIP: shellcheck not available"
  exit 0
fi

base=$(readlink -f $(dirname $0)/..)

check_shell_usage() {
  script="$1"

  failed_checks=0

  if grep -q '#!/bin/sh' $script && ! grep -q 'set -eu' $script; then
    echo "$script: no 'set -eu'!'"
    failed_checks=$(($failed_checks + 1))
  fi

  if ! checkbashisms --force $script; then
    failed_checks=$(($failed_checks + 1))
  fi

  if ! shellcheck --external-sources --shell dash "$script" >/dev/null 2>&1; then
    # not failing on shellcheck issues yet
    echo "W: shellcheck reports warnings on $script; please fix them"
  fi

  return $failed_checks
}
scripts="$(cd $base && find bin/ backends -type f -executable | xargs grep -l '#!/bin/sh') $(cd $base && echo lib/*.sh)"
script_test_names=""

for f in $scripts; do
  ff=$(echo "$f" | sed -e 's/[^a-zA-Z0-9]\+/_/g')
  script_test_names="${script_test_names} test_${ff}"
  eval "test_$ff() { check_shell_usage '$base/$f' || assertTrue \"$f shell usage problems. See messages above\" '${SHUNIT_FALSE}'; }"
done

suite() {
  for f in $script_test_names; do
    suite_addTest "$f"
  done
}

. shunit2
