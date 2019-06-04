#!/bin/bash

echo "Running as user vagrant"
cd /vagrant
./tools/init-dev.sh
make
./bin/debci migrate
./bin/debci setup-chdist
echo "Development virtual machine is installed!"