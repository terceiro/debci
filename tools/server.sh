#!/bin/sh

set -e

# Note the line below: this script is for development only. DO NOT EVER use
# this script for a production deployment.
export FAKE_CERTIFICATE_USER=$USER

case $# in
  0)
    port=8080
    ;;
  1)
    port="$1"
    ;;
  *)
    echo "usage: $0 [PORT]"
    ;;
esac

echo "I: Web UI at http://localhost:$port/"
echo "I: Hit Control+C to stop"
echo ""
exec rerun --no-notify --background --dir lib -p '**/*.rb' -- rackup --include lib --port="$port"
