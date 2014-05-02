class system::users (
  $config   = undef,
) {
  $defaults = {
    ensure   => 'present',
    shell    => '/bin/bash'
  }
  if $real {
    $type = 'user'
  }
  else {
    $type = '@user'
  }
  if $config {
    system_create_resources($type, $config, $defaults)
  }
  else {
    $hiera_config = hiera_hash('system::users', undef)
    if $hiera_config {
      system_create_resources($type, $hiera_config, $defaults)
    }
  }
}
