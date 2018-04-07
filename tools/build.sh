#!/bin/sh

set -e

rerun --background --dir lib,docs --exit -- make
