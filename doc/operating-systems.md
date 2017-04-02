# Operating systems

## As a language construct

Some Spit-sh constructs dynamically change per operating system. For
example, basic subroutines (functions) can be declared with different
bodies per operating system (but same parameters).

```perl6
    sub do-something($with) on {
        Debian { ... }
        CentOS { ... }
        # ...
    }
```

Core classes use this feature to wrap OS specific commands and
procedures in a consistent interface. For
example, [Pkg](classes/Pkg.md) interfaces with the
OS's package manager. [Pkg.install](classes/Pkg.md#install) uses `yum`
on RHEL and `apt-get` on Debian.

## Support

Right now the only two OS variants that pass the spec are Debian and RHEL.
### Operating System Taxonomy
* [UNIXish](#unixish)
  * [POSIX](#posix)
    * [GNU](#gnu)
      * [Debian](#debian)
        * [Ubuntu](#ubuntu)
      * [Fedora](#fedora)
        * [RHEL](#rhel)
          * [CentOS](#centos)
    * [BSD](#bsd)
  * [BusyBox](#busybox)
    * [Alpine](#alpine)

### Alpine
 Alpine linux distribution: https://alpinelinux.org/
### BSD
 For OS's that are variants of the Berkely Software Distribution. See: [wikipedia](https://en.wikipedia.org/wiki/Berkeley_Software_Distribution). **note**: No BSD based OS is tested or working at all atm.
### BusyBox
 For OS's that have the BusyBox UNIX utilities
### CentOS
 CentOS linux distribution [CentOS](https://www.centos.org/)
### Debian
 For OS's based on the [Debian linux distribution](https://www.debian.org/)
### Fedora
 For OS's based on the [Fedora linux distribution](https://getfedora.org/)
### GNU
 For OS's that have [GNU core utilities](https://www.gnu.org/software/coreutils/coreutils.html) installed by default.
### POSIX
 For OS's that that conform to The Open Group's latest "Base Specifications" for the shell enironment. See: http://pubs.opengroup.org/onlinepubs/9699919799/
### RHEL
 For OS's based on the [Redhat Enterprise Linux distribution](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)
### UNIXish
 Anything UNIXish. Right now everything is a child of this.
### Ubuntu
 For OS's based on the [Ubuntu linux distribution](https://www.ubuntu.com/)
