#!/bin/sh

set -eu

if ! which shellcheck >/dev/null 2>&1; then
  echo "SKIP: shellcheck not available"
  exit 0
fi

base=$(readlink -f "$(dirname "$0")"/..)
cd "${base}"

failed_checks=0

check_shell_usage() {
  script="$1"

  if grep -q '#!/bin/sh' "${script}" && ! grep -q 'set -eu' "${script}"; then
    echo "$script: no 'set -eu'!'"
    failed_checks=$((failed_checks + 1))
  fi

  log=$(mktemp)

  if ! shellcheck --external-sources --shell dash "$script" > "$log" 2>&1; then
    if grep -q "^${script}\$" tools/shellcheck.ignore; then
      echo "W: shellcheck reports warnings on $script; please fix them"
    else
      echo "E: shellcheck reports unexpected warnings on $script"
      cat "${log}" | sed -e 's/^/  /'
      failed_checks=$((failed_checks + 1))
    fi
  fi
  rm -f "${log}"
}

scripts="$@"
if [ -z "${scripts}" ]; then
  scripts="$(find bin/ backends -type f -executable -print0 | xargs --null grep -l '#!/bin/sh') $(echo lib/*.sh)"
fi

for f in $scripts; do
  check_shell_usage "${f}"
done

echo "Unexpected failures: ${failed_checks}"
if [ "$failed_checks" -gt 0 ]; then
  exit 1
fi
