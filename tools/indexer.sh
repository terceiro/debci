#!/bin/sh

mkdir -p data/autopkgtest-incoming/

rerun -x \
  --name debci-generate-index \
  --dir data/autopkgtest-incoming/ \
  --pattern '**/duration' \
  --background \
  -- ./bin/debci generate-index
