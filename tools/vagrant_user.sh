#!/bin/bash

set -eux

cd /vagrant
./tools/init-dev.sh
make
./bin/debci migrate
./bin/debci setup-chdist
set +x
echo "Development virtual machine is installed!"
