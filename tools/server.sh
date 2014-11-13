#!/bin/sh

case $# in
  0)
    port=8888
    ;;
  1)
    port="$1"
    ;;
  *)
    echo "usage: $0 [PORT]"
    ;;
esac

document_root="$(dirname $0)/../public"

conffile=$(mktemp)
cleanup() {
  rm -rf "$conffile"
}
trap cleanup INT TERM EXIT

cat > "$conffile" <<-EOF
server.document-root = "$document_root"
server.port = $port
include_shell "/usr/share/lighttpd/create-mime.assign.pl"
mimetype.assign += (".log" => "text/plain; charset=utf-8")
dir-listing.encoding        = "utf-8"
server.dir-listing          = "enable"
index-file.names            = ("index.html", "index.htm")
server.modules             += ("mod_setenv")
\$HTTP["url"] =~ "\.log\.gz" {
  server.error-handler-404 = "/notfound.log.gz"
  setenv.add-response-header = (
    "Content-Encoding" => "gzip",
    "Content-Type" => "text/plain; charset=utf-8"
  )
}
server.modules             += ("mod_rewrite")
url.rewrite-if-not-file = (
  "^(.*\.log)\$" => "\$1.moved"
)
server.modules             += ("mod_redirect")
url.redirect = (
  "^(.*\.log)\.moved\$" => "\$1.gz"
)
EOF

echo "I: Go to: http://localhost:$port/"
echo "I: Hit Control+C to stop"
echo ""
exec /usr/sbin/lighttpd -f "$conffile" -D
