#!/bin/sh

set -e

exec rerun --no-notify --background --dir lib,docs --exit -- make
