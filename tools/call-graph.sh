#!/bin/sh

set -eu

if [ $# -eq 0 ]; then
  programs=$(find bin/ -type f -name 'debci-*' | xargs -n 1 basename)
  functions_file=lib/functions.sh
else
  programs=""
  functions_file="$@"
fi

the_functions=$(sed -e '/^\S\+()/!d; s/().*//' "$functions_file")

echo "digraph \"debci call graph\" {"

# declare function nodes
echo "  subgraph cluster_functions {"
for func in $the_functions; do
  echo "    \"${func}\" [shape=ellipse];"
done
echo "    label=\"$functions_file\";"
echo "    graph[style=dashed];"
echo "  }"

# declare program nodes
for program in $programs; do
  echo "  \"${program}\" [shape=box,style=filled,bgcolor=yellow];"
done

# calls from programs
for caller in $programs; do
  for callee in $programs $the_functions; do
    if [ "$caller" != "$callee" ] && grep -q "$callee" bin/"$caller"; then
      echo "  \"${caller}\" -> \"${callee}\";"
    fi
  done
done

# calls from functions
while read line; do
  case "$line" in
    \#*)
      continue
      ;;
  esac
  if echo "$line" | grep -q '^\S*()'; then
    func=$(echo "$line" | sed -e 's/().*//')
  else
    if echo "$line" | grep -q '^}$'; then
      func=
    else
      if [ -n "$func" ]; then
        for f in $the_functions; do
          if echo "$line" | grep -q "\b$f[^=]\|$f\$"; then
            echo "  \"$func\" -> \"${f}\";"
          fi
        done
      fi
    fi
  fi
done < "$functions_file"

echo "}"
