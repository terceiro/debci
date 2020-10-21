#!/bin/bash

echo "Running as root"
export DEBIAN_FRONTEND=noninteractive
echo "deb http://deb.debian.org/debian buster-backports main" > /etc/apt/sources.list.d/backports.list
apt-get -y update
apt-get -qqyt buster-backports install autopkgtest
apt-get -qqy install make ruby git debootstrap
cd /vagrant
apt-get -qqy build-dep .
