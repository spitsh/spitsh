# 👻 Spook in the Shell 👻 (Spit-sh) [![Build Status](https://travis-ci.org/spitsh/spitsh.svg?branch=master)](https://travis-ci.org/spitsh/spitsh)

**Sp**ook **i**n **t**he **Sh**ell (Spit or Spit-sh) is a
language/compiler that outputs shell scripts. It compiles a strongly
typed Perl 6 like language called "Spook" into `/bin/sh` compatible
scripts. It's main purpose is devops/infrastructure related
tasks. Current features include:

- Compile time type checking
- Basic libraries/modules
- Test module for outputting TAP
- Useful builtin classes and functions
- Running and testing scripts in Docker
- Logging to standard output

Everything about the language and compiler is still experimental. I am
thinking about pivoting a bit into compiling golang to create
standalone binaries instead of shell scripts. 🤔

## Example
To get an idea of what Spit is consider the following basic program:

``` perl 6
.install unless Pkg<nc>; # install nc unless it's already there
ok Cmd<nc>,"nc command exists now"; # test the nc command is there

```

You can compile this for CentOS from the command line like:

``` shell
spit eval --os=centos  '.install unless Pkg<nc>; ok Cmd<nc>,"nc command exists now"'
```

Which ouputs the following shell at the time of writing:

``` shell
BEGIN(){
  e(){ printf %s "$1"; }
  exec 4>/dev/null
  installed(){ yum list installed "$1" >&4 2>&4; }
  install(){ yum install -y $1 >&4 2>&4; }
  exists(){ command -v "$1" >&4; }
  exec 3>&1
  say(){ printf '%s\n' "$1" >&3; }
  note(){ printf '%s\n' "$1" >&2; }
  die(){ note "$1" && kill "-TERM" $$ >&4; }
  ok(){ test "$1" && say "✔ - $2" || die "✘ - $2"; }
}
MAIN(){
  if ! installed nc; then
    install nc
  fi
  ok "$(exists nc && e 1)" 'nc command exists now'
}
BEGIN && MAIN
```
If you have docker installed you can test this with:

``` shell
spit eval --in-docker=centos '.install unless Pkg<nc>; ok Cmd<nc>,"nc command exists now"'
✔ - nc command exists now
```

Unfortunately on Debian the package is named 'netcat'. Let's deal with that:

``` perl 6
# install-nc.sp
constant Pkg $nc = on {
    Debian { 'netcat' }
    Any    { 'nc' } # the default
};

.install unless $nc;
ok Cmd<nc>,"nc command exists now";
```

And now it should work on both the RHEL and Debian families of
Linux distributions.

```
spit  compile install-nc.sp --in-docker=debian:latest
✔ - nc command exists now
```

## Install

Spit is written in Perl 6 and
requires [rakudo](https://github.com/rakudo/rakudo) and something to
install Perl 6 ecosystem modules with
like [zef](https://github.com/ugexe/zef).

```shell
zef install Spit
```
and run
```shell
spit eval 'say "hello world"'
```
To check it's working.

## Documentation

The documentation is pretty useless at the moment because the tooling has
fallen far behind the language. What exists is under: [doc/](doc).

## Project Layout

* The Perl 6 Spit compiler module is in `lib`
* The actual Spit source code is under `resources/src`
* The core spit modules are under `resouces/core-lib`
* The spec tests are in `spec`.
