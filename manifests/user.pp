#
#
# parameters:
# [*name*] Name of user
# [*group*] Name of user's primary group (defaults to user name)
# [*locked*] Whether the user account should be locked.
# [*sshkeys*] List of ssh public keys to be associated with the
# user.
# [*managehome*] Whether the home directory should be removed with accounts
# [*system*] Whether the account should be a member of the system accounts
#
define accounts::user(
  Enum['present', 'absent'] $ensure        = 'present',
  Pattern[/^\//] $shell                    = '/bin/bash',
  String $comment                          = $name,
  Optional[Pattern[/^\//]] $home           = undef,
  Optional[Numeric] $home_mode             = undef,
  Optional[Integer] $uid                   = undef,
  Optional[Integer] $gid                   = undef,
  String $group                            = $name,
  Array[String] $groups                    = [ ],
  Boolean $create_group                    = true,
  Enum['inclusive', 'minimum'] $membership = 'minimum',
  Optional[Boolean] $forcelocal            = undef,
  String $password                         = '!!',
  Boolean $locked                          = false,
  Array[String] $sshkeys                   = [],
  Boolean $purge_sshkeys                   = false,
  Boolean $managehome                      = true,
  Optional[String] $bashrc_content         = undef,
  Optional[String] $bashrc_source          = undef,
  Optional[String] $bash_profile_content   = undef,
  Optional[String] $bash_profile_source    = undef,
  Boolean $system                          = false,
  Boolean $ignore_password_if_empty        = false,
  Optional[String] $forward_content        = undef,
  Optional[String] $forward_source         = undef,
) {

  if $home {
    $home_real = $home
  } elsif $name == 'root' {
    $home_real = $::osfamily ? {
      'Solaris' => '/',
      default   => '/root',
    }
  } else {
    $home_real = $::osfamily ? {
      'Solaris' => "/export/home/${name}",
      default   => "/home/${name}",
    }
  }

  if $locked {
    case $::operatingsystem {
      'debian', 'ubuntu' : {
        $_shell = '/usr/sbin/nologin'
      }
      'solaris' : {
        $_shell = '/usr/bin/false'
      }
      default : {
        $_shell = '/sbin/nologin'
      }
    }
  } else {
    $_shell = $shell
  }

  # Check if user wants to create the group
  if $create_group {
    # Ensure that the group hasn't already been defined
    if $ensure == 'present' and ! defined(Group[$group]) {
      group { $group:
        ensure     => $ensure,
        gid        => $gid,
        system     => $system,
        forcelocal => $forcelocal,
      }
    # Only remove the group if it is the same as user name as it may be shared
    } elsif $ensure == 'absent' and $name == $group {
      group { $group:
        ensure     => $ensure,
        forcelocal => $forcelocal,
      }
    }
  }

  if  $password == '' and $ignore_password_if_empty {
    user { $name:
      ensure         => $ensure,
      shell          => $_shell,
      comment        => "${comment}", # lint:ignore:only_variable_string
      home           => $home_real,
      uid            => $uid,
      gid            => $group,
      groups         => $groups,
      membership     => $membership,
      managehome     => $managehome,
      purge_ssh_keys => $purge_sshkeys,
      system         => $system,
      forcelocal     => $forcelocal,
    }
  } else {
    user { $name:
      ensure         => $ensure,
      shell          => $_shell,
      comment        => "${comment}", # lint:ignore:only_variable_string
      home           => $home_real,
      uid            => $uid,
      gid            => $group,
      groups         => $groups,
      membership     => $membership,
      managehome     => $managehome,
      password       => $password,
      purge_ssh_keys => $purge_sshkeys,
      system         => $system,
      forcelocal     => $forcelocal,
    }
  }

  if $create_group {
    if $ensure == 'present' {
      Group[$group] -> User[$name]
    } else {
      User[$name] -> Group[$group]
    }
  }

  if $managehome {
    accounts::home_dir { $home_real:
      ensure               => $ensure,
      mode                 => $home_mode,
      bashrc_content       => $bashrc_content,
      bashrc_source        => $bashrc_source,
      bash_profile_content => $bash_profile_content,
      bash_profile_source  => $bash_profile_source,
      forward_content      => $forward_content,
      forward_source       => $forward_source,
      user                 => $name,
      group                => $group,
      sshkeys              => $sshkeys,
      require              => [ User[$name] ],
    }
  } elsif $sshkeys != [] {
      warning("ssh keys were passed for user ${name} but \$managehome is set to false; not managing user ssh keys")
  }
}
