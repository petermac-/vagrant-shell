box      = 'puppetlabs-precise64'
hostname = 'techlocal.com'
guestip  = '192.168.50.200'
hostip   = '192.168.1.131'
ram      = '512'

Vagrant.configure("2") do |config|

  # config.hostmanager.enabled = true
  # config.hostmanager.manage_host = true
  # config.hostmanager.ignore_private_ip = false
  # config.hostmanager.include_offline = true

  config.vm.define "devbox" do |devbox|

    devbox.vm.network :private_network, ip: guestip
    devbox.vm.network :forwarded_port, guest: 80, host: 8900

    devbox.vm.synced_folder "www", "/var/www"
    devbox.vm.synced_folder "restore", "/tmp/restore"
    devbox.vm.box               = box
    devbox.vm.box_url           = "http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-1310-x64-virtualbox-nocm.box"
    devbox.vm.hostname          = hostname
    # devbox.ssh.forward_agent    = true
    # devbox.ssh.private_key_path = [ 'C:/Users/Peter/.vagrant.d/insecure_private_key', '~/.ssh/id_rsa' ]

    devbox.vm.provider "virtualbox" do |v|
      v.name = hostname
    end

    devbox.vm.provision :shell, inline: <<-eos
    #!/bin/bash
    cd /vagrant
    sudo bash setup.sh
    eos
  end

end