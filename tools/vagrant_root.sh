#!/bin/bash

echo "Running as root"
export DEBIAN_FRONTEND=noninteractive
echo "deb http://deb.debian.org/debian stretch-backports main" >> /etc/apt/sources.list
apt-get -y update
apt-get -qqyt stretch-backports install autopkgtest
apt-get -qqy install make ruby git debootstrap
cd /vagrant
apt-get -qqy build-dep .
