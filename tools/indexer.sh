#!/bin/sh

set -eu

dir=`$(dirname $0)/../bin/debci config --values-only autopkgtest_basedir`

mkdir -p "$dir"

./bin/debci migrate

exec rerun \
  --no-notify \
  --background \
  --exit \
  --dir "$dir" \
  --pattern '**/log.gz' \
  -- ./bin/debci update
