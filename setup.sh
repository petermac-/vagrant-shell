#!/bin/bash

set -e

####################################################################
# Vars
####################################################################
if [[ ! -f config ]]; then
  echo "Error! Rename config.example to config and edit the default values."
  exit 1
else
  source "config"
fi

if [[ "$EUID" -ne "0" ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

restart_prompt=1

####################################################################
# Utility Functions
####################################################################
## Return values:
# 0 - package installed
# 1 - package not installed
package_installed?() {
  dpkg -L "$1" > /dev/null 2>&1
  if [[ "$?" -eq 1 ]]; then
    return 1
  else
    return 0
  fi
}

## Return values:
# 0 - user exists
# 1 - user does not exist
user_exists?() {
  if id -u "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

## Return values:
# 0 - service installed
# 1 - service not installed
service_installed?() {
  if hash "$1" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

####################################################################
# Update, upgrade, & install some initial packages
####################################################################
apt-get -qqy update
apt-get -qy upgrade
if [[ "$dist_upgrade" -eq 1 ]]; then
  apt-get -qy dist-upgrade
fi
apt-get -qy autoremove

apt-get install -qy build-essential git git-core curl wget zip unzip unattended-upgrades python-setuptools gnupg

####################################################################
# Create USER
####################################################################
if ! user_exists? "$user" && [ ! -z "$user" ]; then
  useradd --create-home --shell /bin/bash --no-user-group --gid adm --groups sudo --uid 500 --password "$user_password" "$user"
fi

####################################################################
# Build and install Nginx from source
####################################################################
if [[ "$install_nginx" -eq 1 ]]; then
  # mysql install fails because of interactive prompt requesting root password
  #   - fixed using debconf-set-selections & export DEBIAN_FRONTEND=noninteractive for a noninteractive prompt
  if ! package_installed? "mysql-server"; then
    debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
    debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
    apt-get -qy install mysql-server
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get -fy install

  if ! package_installed? "php5-mysql"; then
    apt-get -y install php5-mysql php5-fpm libssl-dev build-essential zlib1g-dev libpcre3 libpcre3-dev
  fi

    ####################################################################
    # Restore php pool
    ####################################################################
    if ! user_exists? "$php_pool_user"; then
      adduser --system --home /var/www --shell /bin/sh --no-create-home --group --disabled-password --disabled-login --gecos "" "$php_pool_user"
      if user_exists? "$user"; then
        usermod -a -G "$php_pool_user" "$user"
      fi
    fi

    if ! service_installed? "nginx"; then
      if [ ! -f /etc/php5/fpm/pool.d/www.conf ]; then
        echo "www.conf file is missing"
        exit 1
      fi

      if [[ ! -f /etc/php5/fpm/pool.d/www.conf.orig ]]; then
        cp /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf.orig
      fi

      cp "$files_to_restore/php/pool.d/www.conf" /etc/php5/fpm/pool.d/www.conf
      cp "$files_to_restore/php/pool.d/wwwte.conf" /etc/php5/fpm/pool.d/wwwte.conf

      if hash php5-fpm 2>/dev/null; then
        service php5-fpm restart
      else
        echo "php5-fpm service not found, exiting..."
        exit 2
      fi

      ####################################################################
      # Create a log folder in /var/www
      ####################################################################
      mkdir -p /var/www/logs
      chown -R "$php_pool_user":"$php_pool_user" /var/www/logs
    fi

  if ! service_installed? "nginx"; then
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

    cp -R "$files_to_restore/nginx/*" /etc/nginx/

    if [[ ! -f /etc/php5/fpm/php.ini.orig ]]; then
      cp /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.orig
    fi
    cp "$files_to_restore/php/php.ini" /etc/php5/fpm/php.ini

    if [[ ! -f /etc/php5/fpm/php-fpm.conf.orig ]]; then
      cp /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.orig
    fi
    cp "$files_to_restore/php/php-fpm.conf" /etc/php5/fpm/php-fpm.conf

    service php5-fpm restart

    cp "$files_to_restore/etc/init.d/nginx" /etc/init.d/nginx
    chmod 0755 /etc/init.d/nginx

    if [[ ! -f /var/log/nginx/static.log ]]; then
      touch /var/log/nginx/static.log
      chown "$php_pool_user":"$php_pool_user" /var/log/nginx/static.log
    fi

    if [[ ! -f /var/www/logs/nginx/access.log ]]; then
      touch /var/www/logs/nginx/access.log
      chown "$php_pool_user":"$php_pool_user" /var/www/logs/nginx/access.log
    fi

    if [[ ! -f /var/www/logs/nginx/error.log ]]; then
      touch /var/www/logs/nginx/error.log
      chown "$php_pool_user":"$php_pool_user" /var/www/logs/nginx/error.log
    fi

    service nginx start
    if ! ps aux | grep "[n]ginx" > /dev/null; then
      echo "nginx wasn't able to start up!"
      exit 2
    fi
  else
    echo "Nginx already installed, skipping installation."
  fi
fi

####################################################################
# Create a 1GB swap file
####################################################################
if [[ "$create_swap" -eq 1 ]] && [[ ! -f /swapfile ]]; then
  dd if=/dev/zero of=/swapfile bs=1024 count=1024k
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab
  echo 0 | sudo tee /proc/sys/vm/swappiness
  echo vm.swappiness = 0 | sudo tee -a /etc/sysctl.conf
  chown root:root /swapfile
  chmod 0600 /swapfile
  restart_prompt=0
fi

####################################################################
# Activate techexplored.com vhost
####################################################################
if [[ ! -z "$activate_vhosts" ]]; then
  if [[ ! -d /etc/nginx/sites-enabled ]]; then
    mkdir /etc/nginx/sites-enabled
  fi

  for site in "${activate_vhosts[@]}"; do
    if [[ ! -f "/etc/nginx/sites-enabled/$site" ]]; then
      ln -s "/etc/nginx/sites-available/$site" "/etc/nginx/sites-enabled/$site"
      mkdir -p "/var/www/$site/public_html"
      chown -R "$php_pool_user":"$php_pool_user" /var/www/logs
      nginx -s reload
    fi
  done
fi

# http://linuxsenthil.blogspot.com/2012/12/how-to-secure-ubuntu-1204-lts-server.html
####################################################################
# Secure Shared Memory
####################################################################
if [[ "$secure_shared_memory" -eq 1 ]] && [[ ! -z "$secure_shared_memory" ]]; then
  while read -r line; do
    if [[ "$line" =~ tmpfs[[:space:]]+/dev/shm[[:space:]]+tmpfs[[:space:]]+defaults,noexec,nosuid[[:space:]]+0[[:space:]]+0$ ]]; then
      secureSharedMemory_status=1
      break
    fi
  done < "/etc/fstab"

  if [[ ! "$secureSharedMemory_status" -eq 1 ]]; then
    secureSharedMemory() {
      echo "tmpfs     /dev/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
    }
    restart_prompt=0
  fi
fi

####################################################################
# Protect su
####################################################################
if [[ "$protect_su" -eq 1 ]] && [[ ! -z "$protect_su" ]]; then
  if [[ $(ls -l /bin/su | awk '{ print $4 }') != "adm" ]]; then
    group=adm
    if groups "$user" | grep "\b$group\b"; then
        echo "$user is already in group $group"
    else
      echo "$user is not in group $group"
      groupadd adm
      usermod -a -G adm "$user"
      if groups "$user" | grep "\b$group\b"; then
        echo "$user has been successfully added to group $group"
      else
        echo "failed to add $user to group $group"
        exit 1
      fi
    fi
    dpkg-statoverride --update --add root adm 4750 /bin/su
    restart_prompt=0
  fi
fi

####################################################################
# Harden sysctl
####################################################################
if [[ "$harden_sysctl" -eq 1 ]]; then
  cp "$files_to_restore/sysctl.conf" /etc/sysctl.conf
  sysctl -p
fi

####################################################################
# Prevent IP Spoofing
####################################################################
if [[ "$prevent_ip_spoofing" -eq 1 ]] && [[ ! -z "$prevent_ip_spoofing" ]]; then
  while read -r line; do
    if [[ "$line" =~ nospoof[[:space:]]+on$ ]]; then
      nospoof_status=1
      break
    fi
  done < "/etc/host.conf"

  if [[ ! "$nospoof_status" -eq 1 ]]; then
    echo "nospoof on" >> /etc/host.conf
    restart_prompt=0
  fi
fi

####################################################################
# Install oh-my-zsh
####################################################################
if [[ "$install_zsh" -eq 1 ]]; then
  if [ ! package_installed? "zsh" ]; then
    apt-get -qy install zsh
  fi

  if [[ ! -z "$dotfile_users_setup" ]]; then
    for duser in "${dotfile_users_setup[@]}"; do
      if [[ ! -d "/home/$duser/.oh-my-zsh" ]]; then
        cd "/home/$duser"
        sudo -u "$duser" -H curl -L http://install.ohmyz.sh | sudo -u "$duser" -H sh
      fi

      user_shell="$(sudo -u $duser -H echo $SHELL)"
      if [ "$duser_shell" != "/usr/bin/zsh" ]; then
        sudo chsh "$duser" -s $(which zsh)
      fi
    done
  fi
fi

####################################################################
# Dotfiles Setup
####################################################################
for duser in "${dotfile_users_setup[@]}"; do
  if [[ ! -d "/home/$duser/.dotfiles" ]]; then
    cd "/home/$duser"
    wget --no-check-certificate https://github.com/petermac-/dotfiles/archive/master.zip
    unzip master.zip && rm -f master.zip
    mv dotfiles-master .dotfiles
    chown "$duser" .dotfiles
    cd .dotfiles
    sudo -u "$duser" -H bash setup/bootstrap
  fi
  if [ ! -f "/home/$duser/.gitconfig" ] || [ ! -f "/home/$duser/.zshrc" ] || [ ! -f "/home/$duser/.gemrc" ] || [ ! -f "/home/$duser/.gitignore" ]; then
    cd "/home/$duser/.dotfiles"
    sudo -u "$duser" -H bash setup/bootstrap
  fi
done

####################################################################
# Restart Prompt
####################################################################
if [[ "$restart_prompt" -eq 0 ]]; then
  echo "Updates pending... Restart the server to apply the updates."
  echo -n "Would you like to restart now? [y/n]: "
  read ans
  while [[ "$ans" != "y" ]] && [[ "$ans" != "n"]]; do
    echo "Invalid option: enter y to restart now, or n to manually restart later."
    read ans
  done
  if [[ "$ans" == "y" ]]; then
    reboot
  fi
fi
