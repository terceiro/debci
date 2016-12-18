#!/bin/sh

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

document_root="$(dirname $0)/../public"

echo "I: Go to: http://localhost:$port/"
echo "I: Hit Control+C to stop"
echo ""
cd "$document_root" && python3 -m http.server "$port"
