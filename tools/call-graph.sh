#!/bin/sh

set -eu

programs=$(find bin/ -type f -name 'debci-*' | xargs -n 1 basename)
lib_functions=$(sed -e '/^\S\+()/!d; s/().*//' lib/functions.sh)

echo "digraph \"debci call graph\" {"

# declare function nodes
for func in $lib_functions; do
  echo "  \"${func}\" [shape=ellipse];"
done

# declare program nodes
for program in $programs; do
  echo "  \"${program}\" [shape=box,style=filled,bgcolor=yellow];"
done

for caller in $programs; do
  for callee in $programs $lib_functions; do
    if [ "$caller" != "$callee" ] && grep -q "$callee" bin/"$caller"; then
      echo "  \"${caller}\" -> \"${callee}\";"
    fi
  done
done

echo "}"
