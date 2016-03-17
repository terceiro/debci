#!/bin/sh

mkdir -p data/autopkgtest-incoming/

rerun -x \
  --name debci-update \
  --dir data/autopkgtest-incoming/ \
  --pattern '**/duration' \
  --background \
  -- ./bin/debci update
