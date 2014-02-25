set -e

base=$(readlink -f $(dirname $0)/..)

status=0
for script in ${base}/scripts/*; do
  if grep -q '#!/bin/sh' $script && ! grep -q 'set -e' $script; then
    echo "$script: no 'set -e'!'"
    status=1
  fi
done

exit $status
