# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "debian/stretch64"
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.provision :shell do |shell|
    shell.path = 'tools/vagrant-provision'
  end

  config.vm.provider :libvirt do |libvirt|
    config.vm.synced_folder './', '/vagrant', type: '9p', disabled: false
  end
end
