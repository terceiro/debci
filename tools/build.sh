#!/bin/sh

set -e

rerun --no-notify --background --dir lib,docs --exit -- make
