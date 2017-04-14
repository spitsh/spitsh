# Pkg
 a Pkg represents a package installable via the system's package manager, like `apt-get` or `yum`.
```perl6
if not Pkg<curl> {
   .install;
   say "installed $_ {.version}";
}
```
## Bool
>method Bool( ⟶ [Bool](./Bool.md))

 In Bool context Pkgs return `.installed`
## install
>method install( ⟶ [Bool](./Bool.md))

 Installs the package via the builtin package manager. Returns true if the package was successfully installed.
## installed
>method installed( ⟶ [Bool](./Bool.md))

 Returns True if a version of the package is installed.
## update-pkgs
>method update-pkgs()

 Tells the system specific package manager to update its list of pacakges.
## version
>method version( ⟶ [Str](./Str.md))

 Gets the version of the currently installed package
