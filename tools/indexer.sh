#!/bin/sh

incoming=`$(dirname $0)/../bin/debci config --values-only autopkgtest_incoming_dir`

mkdir -p "$incoming"

while true; do
  inotifywait \
    --event modify \
    --timeout 1 \
    --recursive \
    --quiet --quiet \
    "$incoming"
  ./bin/debci update
done
