#!/bin/bash

VAGRANT_ROOT=$(pwd)

if [[ -f "$VAGRANT_ROOT/bin/pprint" ]]; then
  source "$VAGRANT_ROOT/bin/pprint"
else
  echo "Missing bin/pprint! Exiting..."
  exit 1
fi

####################################################################
# Vars
####################################################################
if [[ ! -f config ]]; then
  eerror "Error! Rename config.example to config and edit the default values."
  exit 1
else
  source "config"
fi

if [[ "$EUID" -ne "0" ]]; then
  eerror "This script must be run as root."
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
  return "$?"
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

## Searches the current directory for a file based on the passed in name $2
## Only needed if Nginx URL does not contain the download filename
## Return values:
# 3 - filename not found
# passed in variable name $1 set equal to the first file name found
get_fname_from_current_folder() {
  filename=$(find . -maxdepth 1 -name "*$1*")
  filename=${filename:2}

  if [[ ! -z $filename ]]; then
    eval "$1=$filename"
  else
    eerror "Filename not found! Exiting..."
    exit 3
  fi
}

get_fname() {
  extension="${2##*.}"
  if [[ "$extension" =~ "zip" ]] || [[ "$extension" =~ "gz" ]] || [[ "$extension" =~ "bz2" ]]; then
    eval "$1=$(basename $2)"
  else
    get_fname_from_current_folder $1
  fi
}

strip_ext() {
  filename="$1=${2%.*}"
  eval "$1=$filename"
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

apt-get install -qy $packages

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
        eerror "www.conf file is missing"
        exit 1
      fi

      if [[ ! -f /etc/php5/fpm/pool.d/www.conf.orig ]]; then
        cp /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf.orig
      fi

      cp "$php_pool_www" /etc/php5/fpm/pool.d/
      cp "$php_pool_wwwte" /etc/php5/fpm/pool.d/

      if hash php5-fpm 2>/dev/null; then
        service php5-fpm restart
      else
        eerror "php5-fpm service not found, exiting..."
        exit 2
      fi

      ####################################################################
      # Create a log folder in /var/www
      ####################################################################
      mkdir -p /var/www/logs

      # fails to apply
      chown -R "$php_pool_user":"$php_pool_user" /var/www/logs
    fi

  ####################################################################
  # Restore MySQL database
  ####################################################################
  if [[ ! -z "$db_name" ]]; then
    if ! mysql -u root -p$db_user_pass -e "use $db_name"; then
      mysql -u root -p$db_user_pass -h localhost < "$db_dump"
    fi
  fi

  if ! service_installed? "nginx"; then
    # Set default vars if not declared
    nginx_configure_params=""
    nginx_pagespeed_dl=${nginx_pagespeed_dl:-https://api.github.com/repos/pagespeed/ngx_pagespeed/tarball/master}
    nginx_psol_dl=${nginx_psol_dl:-https://dl.google.com/dl/page-speed/psol/1.8.31.2.tar.gz}
    nginx_zlib_dl=${nginx_zlib_dl:-http://zlib.net/zlib128.zip}
    nginx_dl=${nginx_dl:-https://api.github.com/repos/nginx/nginx/tarball/master}
    nginx_pcre_dl=${nginx_pcre_dl:-http://downloads.sourceforge.net/pcre/pcre-8.35.tar.bz2}
    nginx_openssl_dl=${nginx_openssl_dl:-ftp://ftp.openssl.org/source/openssl-1.0.1g.tar.gz}

    cd /usr/src
    mkdir "nginx_build"
    cd nginx_build
    if [[ "$nginx_pagespeed_install" -eq 1 ]]; then
      wget --no-check-certificate $nginx_pagespeed_dl
      get_fname_from_current_folder master
      tar -xzvf $master && rm -f $master
      get_fname_from_current_folder ngx_pagespeed
      mv $ngx_pagespeed "ngx_pagespeed"

      cd "ngx_pagespeed"
      # http://modpagespeed.googlecode.com/svn/tags/
      wget --no-check-certificate $nginx_psol_dl
      get_fname psol $nginx_psol_dl
      tar -xzvf $psol && rm -f $psol # expands to psol/
      chown -R root:root psol
      cd /usr/src/nginx_build
      nginx_configure_params="--add-module=/usr/src/nginx_build/ngx_pagespeed"
    fi

    if [[ "$nginx_fresh_zlib" -eq 1 ]]; then
      wget $nginx_zlib_dl
      get_fname zlib $nginx_zlib_dl
      unzip $zlib && rm -f $zlib
      get_fname_from_current_folder zlib
      nginx_configure_params="$nginx_configure_params --with-zlib=/usr/src/nginx_build/$zlib"
    fi

    wget --no-check-certificate $nginx_dl
    get_fname_from_current_folder master
    tar -xzvf $master && rm -f $master

    curl -s --head $nginx_pcre_dl | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
    # on success (page exists), $? will be 0; on failure (page does not exist or
    # is unreachable), $? will be 1
    if [[ "$?" -eq 0 ]]; then
      wget $nginx_pcre_dl
      get_fname pcre $nginx_pcre_dl
      tar -jxvf $pcre && rm -f $pcre
      get_fname_from_current_folder pcre
      chown -R root:root $pcre
      nginx_configure_params="$nginx_configure_params --with-pcre=/usr/src/nginx_build/$pcre"
    fi

    wget $nginx_openssl_dl
    get_fname openssl $nginx_openssl_dl
    tar -xzvf $openssl && rm -f $openssl
    get_fname_from_current_folder openssl
    nginx_configure_params="$nginx_configure_params --with-openssl-opt=$nginx_openssl_opts --with-openssl=/usr/src/nginx_build/$openssl"

    nginx_configure_params="$nginx_configure_params --prefix=$nginx_prefix --sbin-path=$nginx_sbin_path --conf-path=$nginx_conf_path --pid-path=$nginx_pid_path --error-log-path=$nginx_error_log_path --http-log-path=$nginx_http_log_path --user=$nginx_user --group=$nginx_group $nginx_modules"

    get_fname_from_current_folder nginx
    cd $nginx

    # wget http://nginx.org/patches/patch.spdy-v31.txt && patch -p1 < patch.spdy-v31.txt
    ./configure $nginx_configure_params
    make
    make install
    # gem install passenger --no-ri --no-rdoc
    # passenger-install-nginx-module --nginx-source-dir=/usr/src/nginx-1.5.13 --extra-configure-flags="--add-module=/usr/src/ngx_pagespeed-master --with-zlib=/usr/src/zlib-1.2.8 --prefix=/var/www/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --error-log-path=/var/www/logs/nginx/error.log --http-log-path=/var/www/logs/nginx/access.log --user=wwwte-data --group=wwwte-data --with-pcre=/usr/src/pcre-8.35 --with-openssl-opt=no-krb5 --with-openssl=/usr/src/openssl-1.0.1g --with-http_ssl_module --with-http_spdy_module --with-http_gzip_static_module --with-http_stub_status_module --without-mail_pop3_module --without-mail_smtp_module --without-mail_imap_module"

    cp -rb $nginx_config_files /etc/nginx/

    if [[ ! -f /etc/php5/fpm/php.ini.orig ]]; then
      cp /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.orig
    fi
    cp "$php_ini" /etc/php5/fpm/php.ini

    if [[ ! -f /etc/php5/fpm/php-fpm.conf.orig ]]; then
      cp /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.orig
    fi
    cp "$php_fpm_conf" /etc/php5/fpm/php-fpm.conf

    service php5-fpm restart

    cp "$files_to_restore/etc/init.d/nginx" /etc/init.d/nginx
    chmod 0755 /etc/init.d/nginx

    if [[ ! -d /var/log/nginx ]]; then
      mkdir /var/log/nginx
    fi

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
      eerror "nginx wasn't able to start up!"
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
    if [[ ! -h "/etc/nginx/sites-enabled/$site" ]]; then
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
        eerror "failed to add $user to group $group"
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
# Note: The default install script will issue the following error:
#   Password: chsh: PAM: Authentication failure
# Despite the error the default shell is changed appropriately.
####################################################################
if [[ "$install_zsh" -eq 1 ]]; then
  if ! package_installed? "zsh"; then
    apt-get -qy install zsh
  fi

  if [[ ! -z "$dotfile_users_setup" ]]; then
    for duser in "${dotfile_users_setup[@]}"; do
      if [[ ! -d "/home/$duser/.oh-my-zsh" ]]; then
        cd "/home/$duser"
        sudo -u "$duser" -H curl -L http://install.ohmyz.sh | sudo -u "$duser" -H sh
      fi

      duser_shell="$(sudo -u $duser -H echo $SHELL)"
      if [ "$duser_shell" != "/usr/bin/zsh" ]; then
        sed -i 's/auth       required   pam_shells.so/# auth       required   pam_shells.so/' /etc/pam.d/chsh
        chsh "$duser" -s $(which zsh)
        sed -i 's/# auth       required   pam_shells.so/auth       required   pam_shells.so/' /etc/pam.d/chsh
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
    sudo -u "$duser" -H wget --no-check-certificate https://github.com/petermac-/dotfiles/archive/master.zip
    sudo -u "$duser" -H unzip master.zip && sudo -u "$duser" -H rm -f master.zip
    sudo -u "$duser" -H mv dotfiles-master .dotfiles
    cd .dotfiles/bin
    sudo -u "$duser" -H find . -maxdepth 1 -type f | xargs chmod 770
    cd ../
    sudo -u "$duser" -H bash setup/bootstrap
  fi
  if [ ! -e "/home/$duser/.gitconfig" ] || [ ! -e "/home/$duser/.zshrc" ] || [ ! -e "/home/$duser/.gemrc" ] || [ ! -e "/home/$duser/.gitignore" ]; then
    cd "/home/$duser/.dotfiles"
    sudo -u "$duser" -H bash setup/bootstrap
  fi
done

####################################################################
# Restart Prompt
####################################################################
if [[ "$restart_prompt" -eq 0 ]]; then
  esuccess "Updates pending... Restart the server to apply the updates.\n"
fi
