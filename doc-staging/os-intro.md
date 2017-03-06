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
