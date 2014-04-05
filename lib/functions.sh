#!/bin/sh

set -eu

grep_packages() {
  grep-dctrl "$@" "$debci_chroot_path"/var/lib/apt/lists/*_debian_dists_${debci_suite}_main_binary-${debci_arch}_Packages
}

grep_sources() {
  grep-dctrl "$@" "$debci_chroot_path"/var/lib/apt/lists/*_debian_dists_${debci_suite}_main_source_Sources
}


list_binaries() {
  pkg="$1"
  grep_packages -n -s Package -F Source,Package -X "$pkg" | sort | uniq
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
      tmpfail)
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
