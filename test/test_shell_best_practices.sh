base=$(readlink -f $(dirname $0)/..)

check_shell_usage() {
  script="$1"

  failed_checks=0

  if grep -q '#!/bin/sh' $script && ! grep -q 'set -eu' $script; then
    echo "$script: no 'set -eu'!'"
    failed_checks=$(($failed_checks + 1))
  fi

  if ! checkbashisms $script; then
    failed_checks=$(($failed_checks + 1))
  fi

  return $failed_checks
}
scripts="$(grep -l '#!/bin/sh' bin/* scripts/* backends/*/*)"
script_test_names=""

for f in $scripts lib/*.sh; do
  ff=$(echo "$f" | sed -e 's/[^a-zA-Z0-9]/_/g')
  script_test_names="${script_test_names} test_${ff}"
  eval "test_$ff() { check_shell_usage '$f' || assertTrue \"$f shell usage problems. See messages above\" '${SHUNIT_FALSE}'; }"
done

suite() {
  for f in $script_test_names; do
    suite_addTest "$f"
  done
}

. shunit2
