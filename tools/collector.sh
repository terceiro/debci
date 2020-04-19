#!/bin/sh

set -eu

exec rerun --no-notify --background --dir lib -p '**/*.rb' -- \
  ./bin/debci collector
