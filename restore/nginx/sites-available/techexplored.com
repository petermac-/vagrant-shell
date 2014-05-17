# www to non-www redirect -- duplicate content is BAD:
# https://github.com/h5bp/html5-boilerplate/blob/5370479476dceae7cc3ea105946536d6bc0ee468/.htaccess#L362
# Choose between www and non-www, listen on the *wrong* one and redirect to
# the right one -- http://wiki.nginx.org/Pitfalls#Server_Name
server {
  # don't forget to tell on which port this server listens
  listen 80;
  listen 443;

  # listen on the www host
  server_name www.techlocal.com;

  # and redirect to the non-www host (declared below)
  # return 301 $scheme://techexplored.com$request_uri;
  return 301 http://techlocal.com$request_uri;
}

server {
  listen 80;

  # listen on the www host
  server_name techlocal.com;

  access_log /var/www/logs/techexplored.com/access.log combined buffer=32k;
  error_log /var/www/logs/techexplored.com/error.log;

  # Path for static files
  root /var/www/techexplored.com/public_html/web;

  index index.php index.html index.htm;

  # Specify a charset
  charset utf-8;

  location / {
    # First attempt to serve request as file, then
    # as directory, then fall back to displaying a 404.
    try_files $uri $uri/ /index.php?q=$uri&$args;
  }

  #location ~ ^/(wp/) {
  #  rewrite ^/wp(/.*)$ $1 last;
  #}

  # Custom 404 page
  error_page 404 /404.html;

  error_page 500 502 503 504 /50x.html;
  location = /50x.html {
    root /var/www/nginx/html;
  }

  # pass the PHP scripts to FastCGI
  location ~ \.php$ {
    try_files $uri =404;
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass unix:/var/run/php5-fpm.wwwte.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    client_max_body_size 2000M;
    #fastcgi_read_timeout 500;
  }

  location ~ /(config|Capfile|Gemfile(\.lock)?|composer(\.lock|\.json)) {
    deny all;
  }

  # deny access to .htaccess files, if Apache's document root
  # concurs with nginx's one
  location ~ /\.ht {
    deny all;
  }

  # Include the basic h5bp config set
  include h5bp/basic.conf;

}
