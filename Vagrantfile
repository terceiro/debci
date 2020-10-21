# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'.freeze

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # contrib has the vboxsf kernel module, which is needed for guest addition
  config.vm.box = ENV['BOX'] || 'debian/contrib-buster64'
  config.vm.network 'forwarded_port', guest: 8080, host: 8080
  config.vm.synced_folder '.', '/vagrant'

  config.vm.provision 'shell', path: 'tools/vagrant_root.sh'
  config.vm.provision 'shell', path: 'tools/vagrant_user.sh', privileged: false
end
