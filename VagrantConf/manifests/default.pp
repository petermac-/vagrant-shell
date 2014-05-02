group { '500':
  ensure     => 'present',
  gid        => '500',
}

group { '501':
  ensure     => 'present',
  gid        => '501',
}

user { 'peter':
  ensure     => 'present',
  groups     => ['adm', 'sudo'],
  uid        => '500',
  gid        => '500',
  home       => '/home/peter',
  shell      => '/bin/zsh',
  managehome => true,
  system     => true,
  require    => Group['500'],
}

user { 'wwwte-data':
  ensure     => 'present',
  uid        => '501',
  gid        => '501',
  home       => '/var/www',
  shell      => '/bin/bash',
  system     => true,
  require    => Group['501'],
}

ohmyzsh::install { 'peter':
  require => User['peter'],
}

file { '/etc/puppet/hiera.yaml':
  ensure => link,
  owner => root,
  group => root,
  source => "/vagrant-puppet/hiera.yaml",
}

class { 'nginx':
  require => User['peter'],
}
