class dependencies {
  package { "ruby-shadow":
    ensure => present,
    provider => gem,
    require => Exec['sudo apt-get install -y build-essential'],
  }
  package { "zsh":
    ensure => present,
    require => Exec['sudo apt-get install -y build-essential'],
  }
  package { "curl":
    ensure => present,
  }
  package { "nano":
    ensure => present,
  }
  package { "git":
    ensure => present,
  }
}
