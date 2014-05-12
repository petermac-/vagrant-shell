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

- Runs initial server update, upgrade, & dist-upgrade
- Installs some common dev packages
- Adds a new user
- Builds and installs Nginx from source
  - Installs MySQL with a root user & default password of `root`
  - Installs php5-fpm
  - Activates specified vhosts
- Adds a new php pool user
- Safe to provision any number of times
- Creates a 1GB swap file
- Secures shared memory
- Protects su usage
- Hardens sysctl
- Prevents IP spoofing by adding `nospoof on` to /etc/host.conf
- Installs and changes default user shell to oh-my-zsh
- Restores my dotfiles repo to the new user and vagrant user

### Nginx Configuration
- `--add-module=/usr/src/ngx_pagespeed-1.7.30.4-beta`
- `--with-zlib=/usr/src/zlib-1.2.8`
- `--prefix=/var/www/nginx`
- `--sbin-path=/usr/sbin/nginx`
- `--conf-path=/etc/nginx/nginx.conf`
- `--pid-path=/var/run/nginx.pid`
- `--error-log-path=/var/www/logs/nginx/error.log`
- `--http-log-path=/var/www/logs/nginx/access.log`
- `--user=www-data`
- `--group=www-data`
- `--with-pcre=/usr/src/pcre-8.35`
- `--with-openssl-opt=no-krb5`
- `--with-openssl=/usr/src/openssl-1.0.1g`
- `--with-http_ssl_module`
- `--with-http_spdy_module`
- `--with-http_gzip_static_module`
- `--with-http_stub_status_module`
- `--without-mail_pop3_module`
- `--without-mail_smtp_module`
- `--without-mail_imap_module`

To-Do
-----
- Will add additional features as needed/requested
