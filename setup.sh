#!/bin/bash

####################################################################
# Vars
####################################################################
user='peter'
php_pool_user='wwwte-data'

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

####################################################################
# Update, upgrade, & install some initial packages
####################################################################
apt-get -y update
apt-get -y upgrade
apt-get install -y build-essential git unzip python-setuptools

apt-add-repository ppa:rquillo/ansible
apt-get -y update
apt-get install ansible

####################################################################
# Create USER
####################################################################
adduser $user --ingroup adm
usermod -a -G sudo $user

####################################################################
# Build and install Nginx from source
####################################################################
# libssl-dev for nginx compile
apt-get -y install mysql-server php5-mysql php5-fpm libssl-dev build-essential zlib1g-dev libpcre3 libpcre3-dev

  ####################################################################
  # Restore php pool
  ####################################################################
  adduser --system --home /var/www --shell /bin/sh --no-create-home --group --disabled-login --gecos "" $php_pool_user
  if [ ! -f /etc/php5/fpm/pool.d/www.conf ]; then
    echo "www.conf file is missing"
    exit 1
  fi
  if [ ! -f /etc/php5/fpm/pool.d/www.conf.orig ]; then
    cp /etc/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf.orig
  fi
  cp /tmp/restore/php/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf
  cp /tmp/restore/php/pool.d/wwwte.conf /etc/php5/fpm/pool.d/wwwte.conf
  usermod -a -G $php_pool_user $user

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

exit 100
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

rm -rf /etc/nginx
cp -R /tmp/restore/nginx/* /etc/nginx/

if [ ! -f /etc/php5/fpm/php.ini.orig ]; then
  cp /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.orig
fi
cp /tmp/restore/php/php.ini /etc/php5/fpm/php.ini
if [ ! -f /etc/php5/fpm/php-fpm.conf.orig ]; then
  cp /etc/php5/fpm/php-fpm.conf /etc/php5/fpm/php-fpm.conf.orig
fi
cp /tmp/restore/php/php-fpm.conf /etc/php5/fpm/php-fpm.conf
sed -i 's/listen = 127.0.0.1:9000/listen = /var/run/php5-fpm.sock/g' /etc/ssh/sshd_config
service php5-fpm restart

cp /tmp/restore/etc/init.d/nginx /etc/init.d/nginx
chmod 0755 /etc/init.d/nginx
service nginx start

####################################################################
# Create a 1GB swap file
####################################################################
dd if=/dev/zero of=/swapfile bs=1024 count=1024k
mkswap /swapfile
swapon /swapfile
echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab
echo 0 | sudo tee /proc/sys/vm/swappiness
echo vm.swappiness = 0 | sudo tee -a /etc/sysctl.conf
chown root:root /swapfile
chmod 0600 /swapfile

####################################################################
# Activate techexplored.com vhost
####################################################################
ln -s /etc/nginx/sites-available/techexplored.com /etc/nginx/sites-enabled/techexplored.com
mkdir -p /var/www/techexplored.com/public_html
mkdir /var/www/logs/techexplored.com
chown -R wwwte-data:wwwte-data /var/www/logs
nginx -s reload

# http://linuxsenthil.blogspot.com/2012/12/how-to-secure-ubuntu-1204-lts-server.html
####################################################################
# Secure Shared Memory
####################################################################
secureSharedMemory() {
  echo "tmpfs     /dev/shm     tmpfs     defaults,noexec,nosuid     0     0" >> /etc/fstab
}

####################################################################
# Project su
####################################################################
group=adm
if groups $username | grep "\b$group\b"; then
    echo "$username is already in group $group"
else
  echo "$username is not in group $group"
  groupadd adm
  usermod -a -G adm $user
  if groups $username | grep "\b$group\b"; then
    echo "$username has been successfully added to group $group"
  else
    echo "failed to add $username to group $group"
    exit 1
  fi
fi
dpkg-statoverride --update --add root adm 4750 /bin/su

####################################################################
# Harden sysctl
####################################################################
cp /tmp/restore/sysctl.conf /etc/sysctl.conf
sudo sysctl -p

####################################################################
# Prevent IP Spoofing
####################################################################
echo "nospoof on" >> /etc/host.conf
