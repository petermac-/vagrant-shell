box      = 'puppetlabs-precise64'
hostname = 'techlocal.com'
guestip  = '192.168.50.200'

Vagrant.configure("2") do |config|

  config.ssh.forward_agent = true
  config.vm.define "devbox" do |devbox|

    devbox.hostmanager.enabled = true
    devbox.hostmanager.manage_host = true
    devbox.hostmanager.ignore_private_ip = false
    devbox.hostmanager.include_offline = true
    devbox.vm.hostname = hostname
    devbox.vm.network :private_network, ip: guestip
    devbox.hostmanager.aliases = %w(techlocal.com)

    devbox.vm.synced_folder "www", "/var/www"
    devbox.vm.synced_folder "restore", "/tmp/restore"
    devbox.vm.box               = box
    devbox.vm.box_url           = "http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-1310-x64-virtualbox-nocm.box"

    devbox.vm.provider "virtualbox" do |v|
      v.name = hostname
      v.memory = 512
      v.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
      # virtualbox__intnet: true
    end

    devbox.vm.provision :shell, inline: <<-eos
        #!/bin/bash
        cd /vagrant
        sudo bash setup.sh
    eos

  end

end