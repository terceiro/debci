#!/bin/sh

set -eu

base=$(readlink -f $(dirname $(readlink -f $0))/../..)
. $base/lib/environment.sh
prepare_args

/usr/share/autopkgtest/setup-commands/setup-testbed "$@"

rootfs="$1"

# determine whether it's Debian or Ubuntu
script=/usr/share/debootstrap/scripts/$debci_suite
if [ -r $script ]; then
  if grep -q ubuntu.com $script; then
    distro=ubuntu
  else
    distro=debian
  fi
else
  echo "ERROR: $script does not exist; debootstrap is not installed, or $debci_suite is an unknown suite" >&2
  exit 1
fi

if [ "$distro" = debian ]; then
  if [ "$debci_suite" = unstable ]; then
    buildd_suite="buildd-$debci_suite"
  elif [ "$debci_suite" = stable ]; then
    # workaround for bug #880105
    stable=$(curl -Ls http://deb.debian.org/debian/dists/stable/Release | grep-dctrl -n -s Codename '')
    buildd_suite="buildd-$stable-proposed-updates"
  else
    buildd_suite="buildd-$debci_suite-proposed-updates"
  fi
  cat > "${rootfs}/etc/apt/sources.list.d/buildd.list" <<EOF
deb http://incoming.debian.org/debian-buildd $buildd_suite main
deb-src http://incoming.debian.org/debian-buildd $buildd_suite main
EOF
  while ! chroot "$rootfs" apt-get update; do
    echo "I: apt-get update failed, let's wait some time and try again "
    sleep 10
  done
fi

DEBIAN_FRONTEND=noninteractive \
  chroot "$rootfs"  \
  apt-get install dpkg-dev -q -y --no-install-recommends

DEBIAN_FRONTEND=noninteractive \
  chroot "$rootfs"  \
  apt-get clean

chroot "$rootfs"  \
  adduser \
    --system \
    --disabled-password \
    --shell /bin/sh \
    --home /home/debci \
    debci
