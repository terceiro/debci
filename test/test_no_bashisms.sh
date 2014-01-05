set -e

failed=0
for f in $(grep -l '#!/bin/sh' scripts/*) lib/*.sh; do
  if ! checkbashisms $f; then
    failed=$(($failed + 1))
  fi
done

exit $failed
