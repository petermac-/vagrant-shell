vagrant-shell
=============

Download & Install
------------------

Clone the repository
```
git clone https://github.com/petermac-/vagrant-shell.git
```

Configure
---------

- Optionally personalize the hostname variable which is located at the top of the Vagrantfile.
- Rename `config.example` to `config`
- Update variables in config

Usage
-----

```sh
cd vagrant-shell
vagrant up
```

Features
--------

* - has adjustable settings in config
- Runs initial server update, upgrade, & dist-upgrade
- Installs some common dev packages
- *Adds a new user
- Builds and installs Nginx from source
  - *Installs MySQL with a root user & default password of `root`
  - Installs php5-fpm
  - *Activates specified vhosts
- *Adds a new php pool user
- Safe to provision any number of times
- Creates a 1GB swap file
- Secures shared memory
- Protects su usage
- Hardens sysctl
- Prevents IP spoofing by adding `nospoof on` to /etc/host.conf
- Installs and changes default user shell to oh-my-zsh
- Restores my dotfiles repo to the new user and vagrant user

To-Do
-----
- add config options to opt out of some of the currently hard coded features
- add more configurable settings
- ...will add additional features as needed/requested
