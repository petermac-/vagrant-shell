class dependencies {
  package { "ruby-shadow":
    ensure => present,
    provider => gem,
  }
  package { "zsh":
    ensure => present,
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
