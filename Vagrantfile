box      = 'puppetlabs-precise64'
hostname = 'techxlocal.com'
guestip  = '192.168.50.200'

Vagrant.configure("2") do |config|

  config.ssh.forward_agent = true
  # resolve "stdin: is not a tty warning", related issue and proposed fix:
  #     https://github.com/mitchellh/vagrant/issues/1673
  #     https://github.com/mitchellh/vagrant/issues/1673#issuecomment-28287711
  #     https://github.com/mitchellh/vagrant/issues/1673#issuecomment-28288042
  config.ssh.shell                     = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  config.hostmanager.enabled           = true
  config.hostmanager.manage_host       = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline   = true

  config.vm.define "devbox" do |devbox|
    devbox.vm.hostname = hostname
    devbox.vm.network "forwarded_port", guest: 80, host: 80, auto_correct: true
    devbox.hostmanager.aliases = %w(techxlocal.com)

    devbox.vm.synced_folder     "www", "/var/www"
    devbox.vm.synced_folder     "restore", "/tmp/restore"
    devbox.vm.box               = box
    devbox.vm.box_url           = "http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-1310-x64-virtualbox-nocm.box"

    devbox.vm.provider "virtualbox" do |v|
      v.name      = hostname
      v.memory    = 512
      v.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
    end

    devbox.vm.provision :shell, inline: <<-eos
        #!/bin/bash
        cd /vagrant
        sudo bash setup.sh
    eos

  end

end
