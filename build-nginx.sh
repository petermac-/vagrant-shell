
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
