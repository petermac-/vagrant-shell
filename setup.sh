#!/bin/bash

set -e

####################################################################
# Vars
####################################################################
source "/tmp/restore/setup_status"

user='peter'
php_pool_user='wwwte-data'
nginx=0

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if hash nginx 2>/dev/null; then
  nginx=1
fi

####################################################################
# Update, upgrade, & install some initial packages
####################################################################
apt-get -qqy update
apt-get -qy upgrade
apt-get -qy dist-upgrade
apt-get -qy autoremove

# dpkg --configure -a
# apt-get -fy install
# apt-get -y update
apt-get install -qy build-essential git git-core curl wget zip unzip unattended-upgrades python-setuptools gnupg zsh

# apt-add-repository ppa:rquillo/ansible
# apt-get -y update
# apt-get install ansible

####################################################################
# Create USER
####################################################################
# adduser $user --ingroup adm
if ! id -u $user >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --no-user-group --gid adm --groups sudo --uid 500 --password '$6$rounds=100000$r2DvUWNVReVMgErI$thwYEluyYIicV8GG6BI8rfPnJgUBO7SWIp47Zz1gJ/ZtXYq1CrROUVdmstX8Qg2IouW.dnpPmeDvgRas5GlCY.' $user
fi

####################################################################
# Build and install Nginx from source
####################################################################
# libssl-dev for nginx compile
# mysql install fails because of interactive prompt requesting root password
dpkg -L mysql-server > /dev/null 2>&1
if [ $? -eq 1 ]; then
  debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
  debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
  apt-get -qy install mysql-server
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -fy install

dpkg -L php5-mysql > /dev/null 2>&1
if [ $? -eq 1 ]; then
  apt-get -y install php5-mysql php5-fpm libssl-dev build-essential zlib1g-dev libpcre3 libpcre3-dev
fi

  ####################################################################
  # Restore php pool
  ####################################################################
  if ! id -u $php_pool_user >/dev/null 2>&1; then
    adduser --system --home /var/www --shell /bin/sh --no-create-home --group --disabled-password --disabled-login --gecos "" $php_pool_user
    usermod -a -G $php_pool_user $user
  fi

  if [ $nginx -eq 0 ]; then
    if [ ! -f /etc/php5/fpm/pool.d/www.conf ]; then
      echo "www.conf file is missing"
      exit 1
    fi

    if [ ! -f /etc/php5/fpm/pool.d/www.conf.orig ]; then
      cp /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf.orig
    fi

    cp /tmp/restore/php/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf
    cp /tmp/restore/php/pool.d/wwwte.conf /etc/php5/fpm/pool.d/wwwte.conf

    if hash php5-fpm 2>/dev/null; then
      service php5-fpm restart
    else
      echo "php5-fpm service not found, exiting..."
      exit 1
    fi

    ####################################################################
    # Create a log folder in /var/www
    ####################################################################
    mkdir -p /var/www/logs
    chown -R $php_pool_user:$php_pool_user /var/www/logs
  fi

if [ $nginx -eq 0 ]; then
  cd /usr/src
  # wget --no-check-certificate https://github.com/pagespeed/ngx_pagespeed/archive/master.zip
  wget --no-check-certificate https://github.com/pagespeed/ngx_pagespeed/archive/v1.7.30.4-beta.zip
  unzip v1.7.30.4-beta.zip
  cd ngx_pagespeed-1.7.30.4-beta/
  # http://modpagespeed.googlecode.com/svn/tags/
  wget --no-check-certificate https://dl.google.com/dl/page-speed/psol/1.7.30.4.tar.gz
  tar -xzvf 1.7.30.4.tar.gz && rm -f 1.7.30.4.tar.gz # expands to psol/
  chown -R root:root psol

  cd /usr/src
  wget http://zlib.net/zlib128.zip
  unzip zlib128.zip && rm -f zlib128.zip

  wget --no-check-certificate https://github.com/nginx/nginx/archive/v1.7.0.tar.gz
  tar -xzvf ./v1.7.0.tar.gz && rm -f v1.7.0.tar.gz

  wget  ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.35.tar.gz
  tar -xzvf pcre-8.35.tar.gz && rm -f pcre-8.35.tar.gz

  chown -R root:root pcre-8.35
  wget ftp://ftp.openssl.org/source/openssl-1.0.1g.tar.gz
  tar -xzvf openssl-1.0.1g.tar.gz && rm -f openssl-1.0.1g.tar.gz

  cd nginx-1.7.0/
  # wget http://nginx.org/patches/patch.spdy-v31.txt && patch -p1 < patch.spdy-v31.txt
  ./configure --add-module=/usr/src/ngx_pagespeed-1.7.30.4-beta --with-zlib=/usr/src/zlib-1.2.8 --prefix=/var/www/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --error-log-path=/var/www/logs/nginx/error.log --http-log-path=/var/www/logs/nginx/access.log --user=www-data --group=www-data --with-pcre=/usr/src/pcre-8.35 --with-openssl-opt=no-krb5 --with-openssl=/usr/src/openssl-1.0.1g --with-http_ssl_module --with-http_spdy_module --with-http_gzip_static_module --with-http_stub_status_module --without-mail_pop3_module --without-mail_smtp_module --without-mail_imap_module
  make
  make install
  # gem install passenger --no-ri --no-rdoc
  # passenger-install-nginx-module --nginx-source-dir=/usr/src/nginx-1.5.13 --extra-configure-flags="--add-module=/usr/src/ngx_pagespeed-master --with-zlib=/usr/src/zlib-1.2.8 --prefix=/var/www/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --error-log-path=/var/www/logs/nginx/error.log --http-log-path=/var/www/logs/nginx/access.log --user=wwwte-data --group=wwwte-data --with-pcre=/usr/src/pcre-8.35 --with-openssl-opt=no-krb5 --with-openssl=/usr/src/openssl-1.0.1g --with-http_ssl_module --with-http_spdy_module --with-http_gzip_static_module --with-http_stub_status_module --without-mail_pop3_module --without-mail_smtp_module --without-mail_imap_module"

  cp -R /tmp/restore/nginx/* /etc/nginx/

  if [ ! -f /etc/php5/fpm/php.ini.orig ]; then
    cp /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.orig
  fi
  cp /tmp/restore/php/php.ini /etc/php5/fpm/php.ini

  if [ ! -f /etc/php5/fpm/php-fpm.conf.orig ]; then
    cp /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.orig
  fi
  cp /tmp/restore/php/php-fpm.conf /etc/php5/fpm/php-fpm.conf

  sed -i -e 's@listen = 127.0.0.1:9000@listen = /var/run/php5-fpm.sock@g' /etc/php5/fpm/pool.d/www.conf
  service php5-fpm restart

  cp /tmp/restore/etc/init.d/nginx /etc/init.d/nginx
  chmod 0755 /etc/init.d/nginx

  if [ ! -f /var/log/nginx/static.log ]; then
    touch /var/log/nginx/static.log
    chown $php_pool_user:$php_pool_user /var/log/nginx/static.log
  fi

  if [ ! -f /var/www/logs/nginx/access.log ]; then
    touch /var/www/logs/nginx/access.log
    chown $php_pool_user:$php_pool_user /var/www/logs/nginx/access.log
  fi

  if [ ! -f /var/www/logs/nginx/error.log ]; then
    touch /var/www/logs/nginx/error.log
    chown $php_pool_user:$php_pool_user /var/www/logs/nginx/error.log
  fi

  service nginx start
  if ! ps aux | grep "[n]ginx" > /dev/null; then
    echo "nginx wasn't able to start up!"
    exit 2
  fi
fi

####################################################################
# Create a 1GB swap file
####################################################################
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1024 count=1024k
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab
  echo 0 | sudo tee /proc/sys/vm/swappiness
  echo vm.swappiness = 0 | sudo tee -a /etc/sysctl.conf
  chown root:root /swapfile
  chmod 0600 /swapfile
fi

####################################################################
# Activate techexplored.com vhost
####################################################################
if [ ! -d /etc/nginx/sites-enabled ]; then
  mkdir /etc/nginx/sites-enabled
fi

if [ ! -f /etc/nginx/sites-enabled/techexplored.com ]; then
  ln -s /etc/nginx/sites-available/techexplored.com /etc/nginx/sites-enabled/techexplored.com
  mkdir -p /var/www/techexplored.com/public_html
  chown -R wwwte-data:wwwte-data /var/www/logs
  nginx -s reload
fi

# http://linuxsenthil.blogspot.com/2012/12/how-to-secure-ubuntu-1204-lts-server.html
####################################################################
# Secure Shared Memory
####################################################################
if [ $secureSharedMemory_status -eq 0 ]; then
  secureSharedMemory() {
    echo "tmpfs     /dev/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
  }
  sed -i -e 's@secureSharedMemory_status=0@secureSharedMemory_status=1@g' /tmp/restore/setup_status
fi


####################################################################
# Protect su
####################################################################
if [ $protect_su_status -eq 0 ]; then
  group=adm
  if groups $user | grep "\b$group\b"; then
      echo "$user is already in group $group"
  else
    echo "$user is not in group $group"
    groupadd adm
    usermod -a -G adm $user
    if groups $user | grep "\b$group\b"; then
      echo "$user has been successfully added to group $group"
    else
      echo "failed to add $user to group $group"
      exit 1
    fi
  fi
  dpkg-statoverride --update --add root adm 4750 /bin/su
  sed -i -e 's@protect_su_status=0@protect_su_status=1@g' /tmp/restore/setup_status
fi

####################################################################
# Harden sysctl
####################################################################
if [ $harden_sysctl_status -eq 0 ]; then
  cp /tmp/restore/sysctl.conf /etc/sysctl.conf
  sudo sysctl -p
  sed -i -e 's@harden_sysctl_status=0@harden_sysctl_status=1@g' /tmp/restore/setup_status
fi

####################################################################
# Prevent IP Spoofing
####################################################################
if [ $nospoof_status -eq 0 ]; then
  echo "nospoof on" >> /etc/host.conf
  sed -i -e 's@nospoof_status=0@nospoof_status=1@g' /tmp/restore/setup_status
fi

####################################################################
# Install oh-my-zsh
####################################################################
if [ $zsh_status -eq 0 ]; then
  if [ ! -d /home/$user/.oh-my-zsh ]; then
    cd /home/$user
    sudo -u $user -H curl -L http://install.ohmyz.sh | sudo -u $user -H sh
  fi

  user_shell="$(sudo -u $user -H echo $SHELL)"
  if [ "$user_shell" != "/usr/bin/zsh" ]; then
    sudo sed -i -e 's@auth       required   pam_shells.so@#auth       required   pam_shells.so@g' /etc/pam.d/chsh
    sudo chsh $user -s $(which zsh)
    sudo sed -i -e 's@#auth       required   pam_shells.so@auth       required   pam_shells.so@g' /etc/pam.d/chsh
  fi

  if [ ! -d /home/vagrant/.oh-my-zsh ]; then
    cd /home/vagrant
    sudo -u vagrant -H curl -L http://install.ohmyz.sh | sudo -u vagrant -H sh
  fi

  vagrant_shell="$(sudo -u vagrant -H echo $SHELL)"
  if [ "$vagrant_shell" != "/usr/bin/zsh" ]; then
    sudo sed -i -e 's@auth       required   pam_shells.so@#auth       required   pam_shells.so@g' /etc/pam.d/chsh
    sudo chsh vagrant -s $(which zsh)
    sudo sed -i -e 's@#auth       required   pam_shells.so@auth       required   pam_shells.so@g' /etc/pam.d/chsh
  fi

  if [ "$user_shell" = "/usr/bin/zsh" ] && [ "$vagrant_shell" = "/usr/bin/zsh" ]; then
    sed -i -e 's@zsh_status=0@zsh_status=1@g' /tmp/restore/setup_status
  fi
fi
