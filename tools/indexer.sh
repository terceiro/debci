#!/bin/sh

set -eu

incoming=`$(dirname $0)/../bin/debci config --values-only autopkgtest_incoming_dir`

mkdir -p "$incoming"

while true; do
  if inotifywait \
    --event modify \
    --timeout 1 \
    --recursive \
    --quiet --quiet \
    "$incoming"; then
    "echo I: changes in incoming directory; updating"
    ./bin/debci update
  fi
done
