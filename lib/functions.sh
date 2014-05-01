#!/bin/sh

case $- in
  *i*)
    ;;
  *)
    set -eu
    ;;
esac

grep_packages() {
  chdist -d "${debci_data_basedir}/chdist" grep-dctrl-packages ${debci_suite}-${debci_arch} "$@"
}

grep_sources() {
  chdist -d "${debci_data_basedir}/chdist" grep-dctrl-sources ${debci_suite}-${debci_arch} "$@"
}


list_binaries() {
  pkg="$1"
  grep_sources -n -s Binary -F Package -X "$pkg" | sed -s 's/, /\n/g' | sort -u
}


first_banner=
banner() {
  if [ "$first_banner" = "$pkg" ]; then
    echo
  fi
  first_banner="$pkg"
  echo "$@" | sed -e 's/./—/g'
  echo "$@"
  echo "$@" | sed -e 's/./—/g'
  echo
}

indent() {
  sed -e 's/^/    /'
}

autopkgtest_dir_for_package() {
  local pkg="$1"
  pkg_dir=$(echo "$pkg" | sed -e 's/\(\(lib\)\?.\).*/\1\/&/')
  echo "${debci_autopkgtest_dir}/${pkg_dir}"
}


status_dir_for_package() {
  local pkg="$1"
  pkg_dir=$(echo "$pkg" | sed -e 's/\(\(lib\)\?.\).*/\1\/&/')
  echo "${debci_packages_dir}/${pkg_dir}"
}


log() {
  if [ "$debci_quiet" = 'false' ]; then
    echo "$@"
  fi
}


report_status() {
  local pkg="$1"
  local status="$2"
  if [ -t 1 ]; then
    case "$status" in
      skip)
        color=8
        ;;
      pass)
        color=2
        ;;
      fail)
        color=1
        ;;
      tmpfail|requested)
        color=3
        ;;
      *)
        color=5 # should never get here though
        ;;
    esac
    log "${pkg} \033[38;5;${color}m${status}\033[m"
  else
    log "$pkg" "$status"
  fi
}


command_available() {
  which "$1" >/dev/null 2>/dev/null
}
