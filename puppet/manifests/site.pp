# create a new run stage to ensure certain modules are included first
stage { 'pre':
  before => Stage['main']
}

# 1. Install Dependencies
# 2. User Setup
# 3. oh-my-zsh install
# 4. dotfiles clone and symbolic links created

class { 'dependencies':
  stage => 'pre'
}

class { 'known_hosts':
  stage => 'pre'
}

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
