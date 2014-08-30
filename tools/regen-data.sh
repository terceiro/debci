#!/bin/sh

debci_base_dir=$(readlink -f $(dirname $(readlink -f $0))/..)
. $debci_base_dir/lib/environment.sh

rm -rfv $debci_data_basedir/packages
rm -rfv $debci_data_basedir/feeds
rm -rfv $debci_data_basedir/status/*/*/packages.json

cd $debci_base_dir
./bin/debci generate-index
