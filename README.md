# Spook in the Shell Script (Spit-sh) [![Build Status](https://travis-ci.org/spitsh/spitsh.svg?branch=master)](https://travis-ci.org/spitsh/spitsh)

**Sp**ook **i**n **t**he **Sh**ell (Spit or Spit-sh), is Perl-6-like
language and compiler for producing modular, dynamic and testable
shell scripts. Its purpose is to specify and test configurations for
modern UNIX-like systems. **It's very new and experimental and doesn't
do a lot yet**.


## Where it fits
Here are a few of the goals of Spit-sh as a configurtion utility:

- It shouldn't require any software on the target system other than
  `/bin/sh`, the POSIX shell utilities and a package manager.
- It shouldn't try and handle delivery of the scripts to the target
  system. (Other tools can do this).
- It should be appropriate for specifying container images.
- It must be easy to write, document, test and distribute modules.
- Like Perl 6:
  - It must be test-centric and have
    a [specification test suite](spec) written in the language itself.
  - The core classes, symbols and routines should be defined in the
    language itself.
  - It must be -Ofun 👻🐚💕🦋

## Example
To get a picture of where Spit is going take a look at this code:

``` perl6
.install unless Pkg<nc>; # install nc unless it's already there
ok Cmd<nc>,"nc command exists now"; # test the nc command is there

```
You can compile this for CentOS with:

``` shell
spit --os=centos eval '.install unless Pkg<nc>; ok Cmd<nc>,"nc command exists now"'
```
Which ouputs the following (imperfect) shell at the time of writing:

``` shell
BEGIN(){
  exec 4>/dev/null
  installed(){ yum list installed "$1" >&4 2>&4; }
  install(){ yum install -y "$1" >&4 2>&4; }
  exists(){ command -v "$1" >&4; }
  exec 3>&1
  say(){ printf "%s\n" "$1" >&3; }
  die(){ say "$1" && exit 1; }
  ok(){ test "$1" && say \✔" - $2" || die \✘" - $2"; }
  e(){ printf %s "$1"; }
}
MAIN(){
  if ! installed nc; then
    install nc
  fi
  ok "$(exists nc && e 1)" "nc command exists now"
}
BEGIN && MAIN
```
If you have docker installed you can test this with:

``` shell
# at the moment --in-docker --rm's the container
spit --in-docker=centos eval '.install unless Pkg<nc>; ok Cmd<nc>,"nc command exists now"'
✔ - nc command exists now
```

Unfortunately on Debian the package is named 'netcat'. Let's deal with that:

``` perl
constant Pkg $nc = (given $*os {
    when Debian { 'netcat' }
    when RHEL { 'nc' }
    default { 'nc' }
});

.install unless $nc;
ok Cmd<nc>,"nc command exists now";
```

And now it should work on both the RHEL and Debian families of
Linux distributions.

```
spit --in-docker=ubuntu:latest compile install-nc.spt
✔ - nc command exists now
```

## Install

Spit is written in Perl 6 and
requires [rakudo](https://github.com/rakudo/rakudo) and something to
install Perl 6 ecosystem modules with
like [zef](https://github.com/ugexe/zef).

**note** [rakudo star](http://rakudo.org/how-to-get-rakudo/) is too
far behind at the moment. You need to build from rakudo/nom because
Spit uses some features recently added to rakudo. Hopefully it will
keep compatibility with rakudo star in the future.

**note** Spit is very slow atm because it can't precompile its core
SETTING. It has to fully parse the whole SETTING every time you run a
program. Hopefully this can be fixed soon.

```shell
zef install Spit
```
and run
```shell
spit eval 'say "hello world"'
```
To check it's working.

## Documentation

Documentation is very much a work in progress but what exists is under: [doc/](doc).

## Project Layout

* The Perl 6 Spit compiler module is in `lib`
* The actual Spit source code is under `resources/src`
* The core spit modules are under `resouces/core-lib` (right now just `Test.spt`)
* The spec tests are in `spec`.

## Contribute

There's a lot to do before Spit becomes a genuinely useful tool.

* If you like grammars and abstract syntax trees you can
  help develop the compiler
* You can add support for an operating system/userland by writing Spit
  code that passes the [spec tests](spec)
* Try it out, provide bug reports, useful criticism and feature ideas under the
  issues github tab
* Figure out how it works and write documentation
