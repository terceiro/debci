#!/bin/sh

set -eu

debci_base_dir=$(readlink -f $(dirname $(readlink -f $0))/..)
cd $debci_base_dir
. lib/environment.sh
prepare_args

for pkg in $@; do
  prefix=$(expr substr "$pkg" 1 1)
  echo "$pkg"
  rm -rf $debci_data_basedir/.html/packages/$prefix/$pkg
  rm -rf $debci_data_basedir/autopkgtest-incoming/$debci_suite/$debci_arch/$prefix/$pkg
  rm -rf $debci_data_basedir/packages/$debci_suite/$debci_arch/$prefix/$pkg
  rm -rf $debci_data_basedir/autopkgtest/$debci_suite/$debci_arch/$prefix/$pkg
done
