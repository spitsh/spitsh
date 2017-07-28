constant Int $:pkglist-stale = 60*60*24;

constant File $:pkglist-path = on {
    Debian { "/var/lib/apt/lists/"  }
    Alpine { "/var/cache/apk/"  }
    RHEL   { "/var/cache/yum"  }
}

constant Cmd $?pm is logged-as("\c[PACKAGE]") = on {
    Debian { 'apt-get' }
    Alpine { 'apk' }
    RHEL   { 'yum' }
}

#| a Pkg represents a package installable via the system's package
#| manager, like `apt-get` or `yum`.
#|{
    if not Pkg<curl> {
        .install;
        say "installed $_ {.version}";
    }
}
class Pkg {

    #| Tells the system specific package manager to update its list of pacakges.
    static method update-pkglist? on {
        Debian ${$?pm update >debug/warn}
        RHEL   {
            ${$?pm clean expire-cache >debug/warn} &&
              ${$?pm check-update >debug/warn};
            $? != 1
        }
                # apt is noisy for no reason so send it to debug instead of warn
        Alpine ${ $?pm update *>debug }
    }

    static method last-updated-->DateTime on {
        Debian {
            # "partial" seems to get touched whenever apt-get update is run
            $:pkglist-path.add("partial").ctime;
        }
        Alpine { $:pkglist-path.find(name => '*.gz')[0].ctime }
        RHEL ${
            date -d
            ${
                $?pm repolist enabled -v !>warn
                | grep -m1 Repo-expire
                | sed -r 's/.*last: |\)//g'
             }
            '+%FT%T.%3N'
        }
    }

    static method check-update? {
        my $last-updated = Pkg.last-updated;
        if ! ~$last-updated || now().posix - $last-updated.posix > $:pkglist-stale {
            info "Updating package list because it " ~ (
                ~$last-updated
                  ?? "was last updated at $last-updated"
                  !! "doesn't exist"
            );
            Pkg.update-pkglist;
        }
    }

    #| Installs the package via the builtin package manager.
    #| Returns true if the package was successfully installed.
    method install? {
        $self-->List[Pkg].install;
    }

    method ensure-install? {
        $self.installed || $self.install;
    }

    #| Returns True if a version of the package is installed.
    method installed? on {
        Debian ${dpkg -s $self *>X}
        RHEL   ${yum list installed $self *>X}
        Alpine ${apk info -e $self *>X}
    }

    #| Gets the version of the currently installed package
    method version~ on {
        Debian ${dpkg -s $self |sed -n 's/^Version: //p' }
        RHEL   ${yum info installed $self |sed -n 's/Version *: //p'}
        Alpine ${apk version $self | sed -rn '2s/\w+-(\S*).*/\1/p' }
    }

    #| In Bool context Pkgs return `.installed`
    method Bool { $self.installed }

    method prompt-install {
        if prompt("This script requires the '$self' to be installed to continue.\ninstall?", :default) {
            $self.install;
        } else {
            die "unable to install $self";
        }
    }
}

augment List[Pkg] {

    #| Installs the package via the builtin package manager.
    #| Returns true if the package was successfully installed.
    method install? {
        info "Installing pacakges: {$self.join(', ')}";
        on {
            RHEL ${$?pm install -y @$self >debug/warn}
            Debian {
                Pkg.check-update;
                ${
                    $?pm install >debug/warn :DEBIAN_FRONTEND<noninteractive>
                    -y -q --no-install-recommends @$self
                }
            }
            Alpine {
                Pkg.check-update;
                ${$?pm add @$self --no-progress >debug/warn};
            }
        }
    }

}
