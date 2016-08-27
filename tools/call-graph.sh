#!/bin/sh

set -eu

programs=$(find bin/ -type f -name 'debci-*' | xargs -n 1 basename)
lib_functions=$(sed -e '/^\S\+()/!d; s/().*//' lib/functions.sh)

echo "digraph \"debci call graph\" {"

# declare function nodes
echo "  subgraph cluster_functions {"
for func in $lib_functions; do
  echo "    \"${func}\" [shape=ellipse];"
done
echo "    label=\"lib/functions.sh\";"
echo "    graph[style=dashed];"
echo "  }"

# declare program nodes
for program in $programs; do
  echo "  \"${program}\" [shape=box,style=filled,bgcolor=yellow];"
done

# calls from programs
for caller in $programs; do
  for callee in $programs $lib_functions; do
    if [ "$caller" != "$callee" ] && grep -q "$callee" bin/"$caller"; then
      echo "  \"${caller}\" -> \"${callee}\";"
    fi
  done
done

# calls from functions
while read line; do
  if echo "$line" | grep -q '^\S*()'; then
    func=$(echo "$line" | sed -e 's/().*//')
  else
    for f in $lib_functions; do
      if echo "$line" | grep -q "\b$f\b"; then
        echo "  \"$func\" -> \"${f}\";"
      fi
    done
  fi
done < lib/functions.sh

echo "}"
