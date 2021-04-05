#!/bin/sh

set -eu

base=$(readlink -f "$(dirname "$(readlink -f "$0")")/../..")
. "$base/lib/environment.sh"

prepare_args
rootfs="$1"

# determine whether it's Debian or Ubuntu
script="/usr/share/debootstrap/scripts/${debci_suite:?}"
if [ -r "$script" ]; then
  if grep -q ubuntu.com "$script"; then
    distro=ubuntu
  elif grep -q kali.org "$script"; then
    distro=kali
  else
    distro=debian
  fi
else
  echo "ERROR: $script does not exist; debootstrap is not installed, or $debci_suite is an unknown suite" >&2
  exit 1
fi

if [ "$distro" = debian ]; then
  debci-generate-apt-sources \
    --source \
    --buildd \
    -- \
    "$debci_suite" \
    > "$rootfs/etc/apt/sources.list"
  while ! chroot "$rootfs" apt-get update; do
    echo "I: apt-get update failed, let's wait some time and try again "
    sleep 10
  done
fi

# convert apt proxy pointing to the VM's host back to localhost
proxy_opt=
RES=$(chroot "${rootfs}" apt-config shell PROXY Acquire::http::Proxy)
eval "$RES"
if [ -n "$PROXY" ]; then
  proxy_opt="-o Acquire::http::Proxy=$(echo "${PROXY}" | sed -e 's/10.0.2.2/127.0.0.1/')"
fi
# shellcheck disable=SC2086
DEBIAN_FRONTEND=noninteractive \
  chroot "$rootfs"  \
  apt-get install $proxy_opt dpkg-dev ca-certificates -q -y --no-install-recommends

DEBIAN_FRONTEND=noninteractive \
  chroot "$rootfs"  \
  apt-get clean

chroot "$rootfs"  \
  useradd \
    --home /home/debci \
    --create-home \
    debci