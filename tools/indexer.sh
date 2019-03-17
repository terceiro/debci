#!/bin/sh

set -eu

incoming=`$(dirname $0)/../bin/debci config --values-only autopkgtest_incoming_basedir`

mkdir -p "$incoming"

exec rerun \
  --no-notify \
  --exit \
  --dir "$incoming" \
  --pattern '**/exitcode' \
  -- ./bin/debci update
