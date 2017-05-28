## 0.0.29

- **NOTICE**: routine return type syntax has changed:
  - `foo(...-->Type)` is not `sub foo(...)-->Type`
- **New Feature**: Perl 6 style Parameter defaults (!)
  - `sub foo($foo = "bar", :$bar = "bar") {...}`
- **New Feature**: Runtime arguments to `eval`
  - You can now do:
  ```perl6
  my $foo = "bar";
  my $shell = eval(:$foo){ my $*foo; say $*foo };
  ```
  And spit will insert the runtime value for `$foo` into the compiled script
- **New Feature**: `start { }` blocks which are an interface to `&` asynchronous lists
  - It returns a `PID` (maybe one day a promise)
  - Used like:
  ```perl6
      my $pid = start sleep 1000;
      say "waiting for a while";
      sleep 10;
      if $pid {
        note "it's still running. Killing it";
        .kill;
      }
  ```

- `File.write .move and .chmod` return the invocant now.
- Add `Str.substr` which does what you expect
- Add `Str.random` which produces random strings
- Add `List.pick`  (same as Perl 6)
- Add `PID.children` and `PID.descendants`
- Add `&kill` and `List[PID].kill`
- Add `&wait` and `List[PID].wait` and `PID.wait`
- New phasers that run **after** `END`: `FILE-CLEAN` and `CHECK-CLEAN`
- Add `List[JSON].sort($key)` which can sort a list of JSON objects
  based on the value in a certain key
- Add `$*socat` and add it to spit-helper

## 0.0.28

- Add `$*set-delimiter` and `§` quote metachar to refer to it (works
  in '' and "")
- Add `Pair` type
- Add `List[Pair]` as our de-facto dictionary like object. It has:
  - at-key
  - set-key
  - delete-key
  - exists-key
- Add `<...>` and `{...}` postcircumfixes as shortcuts for at-key/set-key
- Add `JSON` class (WIP)
- Add `j{...}` JSON quoting used like `j{ one => 1, two => 2, three => 3}`
- Add `File.sha256`
- Add `$*jq` for getting jq (currently pulls a binary from github)
- Add `Str.substr-re` (WIP leading up to ~~ s/foo/bar/g etc)
- **New Feature**: Perl 6 style C-style for `loop`
``` perl6
# e.g two at a time iteration
my @a = <one two three four>;
loop (my $i = 0; $i < @a; $i += 2) {
    say @a[$i], @a[$i+1];
}
```
- **New Feature**: Perl 6 Q{...} and ｢...｣ quotes
- **New Feature**: Perl 6 "\x[...]" quotes and \a \b \f \r escape
  sequences
- **New Feature**: Slurpy positional parameters:
``` perl6
sub foo($a, $b, *@c) {
    say "$a, $b, @c";
}
```


## 0.0.27

- Add `DateTime.Bool` (which calls .valid)
- Make `lt`, `gt`, `ge` and `le` work
- Add `File.ctime` to get the last changed time from a file
- Add `DateTime.epoch-start` (1970-01-01T00:00:00.000)
- Add resources/tools/spit-helper.spt which builds an image with a few
  useful default things installed. I hope to use it to deploy scripts.
  - Add `spit helper build` to build the helper
  - Add `-h` and `--in-helper` to `spit compile` to run the script in
    the helper
- Add `Str.extract` which treats the content as a tgz and extracts it
- Add `Cmd.path` to get the path to a command
- .call: args syntax works with topic calls
- Add `$?spit-version` to give you the version of spit as a variable

## 0.0.26

Many bug fixes and new features but not much new documentation.

- Add \${ ... } for making a list with command syntax. E.g.
  `my @cmd = ${ printf "foo" }`
- Add short syntax for declaration a routine body as a command. E.g.
  Instead of `sub foo { ${ printf "foo"} }` you can just do
  `sub foo ${printf "foo"}`.
- Add `DateTime` and `Date` (no docs yet)
- `File.touch` returns a Bool
- Add `File.mtime` which returns a `DateTime` of the mtime
- Add `$*gcc-make` for getting gcc, make and libc development headers
- Add `File.cleanup` which will add the file to the list of temp files
  to be cleanup up at END
- Add -D switch to execute script in an already running docker container
- Add `GitHubRepo.release-url` and `.latest-release-url`
- Add `Pkg.ensure-install` which installs it only if a version isn't
  already installed.
- The test harness is now written in spit and lives in `tools/harness`.
- Add `$*docker-socket` to replace `Docker.socket`.
- Add GitHubRepo `$*moby-github`
- Add `Docker.start-sleep` which keeps a container sleeping so it can
  be exec'd into.
- `File.push` now returns the pushed item.
- `Str.write-to` now returns what was written
- Add `Str.append-to` which appends to a file and returns what was appended.


## 0.0.25
- Add .grep and .first for List and File
- Much more piping between commands instead of command substitution.
  Now, something like:
  ```perl6
  say <one two three four five>.grep(/e/).elems;
  ```
  compiles into:
  ```shell
  say "$(list one two three four five|egrep e|elems)";
  ```
  Much much nicer :)
- @self is gone
- You can now augment parameterized classes. E.g List[Int].sum is
  implemented like:

``` perl6
augment List[Int] {
    method +sum { $self.${ awk '{ i += $0 } END { printf i }' } }
}
...
say <1 2 3 4>.sum #->10, only works on List[Int].
```

## 0.0.24

- Added Perl 6 colon method call argument form `class.method: args`
- Added File.archive, which creates a tgz from a directory
- Added File.extract which extracts a tgz to a directory and returns it
- Added Docker.commit which returns a DockerImg
- Added Docker.copy to copy files into a container with `docker cp`.
- Added HTTP.get-file which gets a remote file and saves it to file system.

No docs for the above because it's all WIP

## 0.0.23

- Add Docker, `$*docker`, `$*docker-cli` (WIP)
- Add -s/--mount-docker-socket switches to mount /var/run/docker.sock
  if running script inside a container.
- Add `$*curl`
- Add File.move-to
- POSIX OS has been removed
- Linux OS has been added
- `("foo:$_" if $foo)` now reduces down to `${foo:+"foo:$foo"}`
- `$*interactive` now defaults to False
  - -i cli switch to set `$*interactive` to `$?IN.tty`
  - -I cli switch to force `$*interactive` to `True`

## 0.0.22

- CLI overhauled. See spit --help.
- option expression prefix changed from '->' to just ':'. You can now
  escape it with a \: if you want to start with a literal ':'

## 0.0.21

- Add File.mkdir
- Add File.cd
- Add a :dir option to File.tmp to create a tmp directory.
- Add spit-dev command in root of src to be used instead of ./bin/spit
  for development.
- Renamed $$ to $?PID
- Renamed File.create to File.touch
- Renamed File.child to File.add
- Routines that just do concatenation can now be inlined

## 0.0.20

- FD.next-free now uses /proc to figure out what FD is free.
- Fixed bug where `>` type comparisons would fail if both sides were
  know at compile time.


## 0.0.19

- File.read renamed to File.slurp
- Type blessing syantax changed from File{"foo"} to File("foo")
- Add GitHubRepo which represents a guthub repo owner/repo-name like
  `GitHubRepo<spitsh/spitsh>`
- Add GitURL, which represents `git clone`'able string like
  `GitURL<https://github.com/spitsh/spitsh.git/>`
- Add $*git, which gives you the git command
- Add &prompt which prompts the user with a string and returns their answer as a Bool
- Add $?IN, basically just FD(0)
- Add File.find which is an interface to find(1)
- Add PID.kill which sends a signal to a process
- Add &sleep, a wrapper around sleep(1)
- Add env declarator to reserve shell environment variable names. Used like:
  ```perl6
    env $MY_ENV_VAR;
    #or
    env $MY_ENV_VAR = "foo";
  ```

## 0.0.18
- Regex system redesigned and re-implemented
  - regex parsing is now done during the parse phase (no more 2-pass parsing)
  - The compiler now has the responsibility of inserting
    interpolations into the regex pattern that is eventually chosen

- Add PID class which is a blessed int representing a process ID
- Add $?PID which holds the PID for the main script
- Add $$ which gives access to the shell's $$
- spit eval now reads from STDIN if it doesn' have an argument


## 0.0.17
- add Str.matches which is like .match but doesn't set `@/`.
- ~~ and ACCEPTS have been overhauled. Classes now can have their own
  .ACCEPTS method which controls what ~~ returns.
- `SPIT_SETTING_DEV=1` can be set when you are working on core code to
  recompile the SETTING after you make changes.

## 0.0.16

- Precompilation of CORE setting and core modules. Compilation is much faster now.


## 0.0.15

- new .NAME meta-method which returns the name of a variable
  `$a.NAME` -> "a" or "a_1" etc
- Better inlining of blocks all around
- Reworked FD after investigating how `exec(1)` actually works:
  - .open-w and .open-r been removed. They
  both did the same thing. They are replaced with .dup which AFAICT is
  what exec is actually doing when you use it with two file descriptors
  - open-file-w/open-file-r has been renamed to open-w and open-r
  - open-rw has been added
  - writable has been renamed to is-open which is what it actually does.
- Added FD.get and FD.getc (which isn't working on Debian/dash yet)

## 0.0.14

- `$?` variable representing the exit status of the last command
  executed.
- You can now have multiple statements inside `(...)`. E.g.
  ```perl6
  say ( say 'inside goes first!'; "the will print second");
  ```
  This is especially useful in conditionals
  ```perl6
  my $str = '';
  my @a =  ^100;
  my $i = 0;
  $i++ while ($str ~= @a[$i]; $str.chars < 20);
  say $str;
  ```
- `.match` now retruns a `Bool` and sets the new `@/` variable with the matches.
  ```perl6
  my $regex = rx‘^(.+)://([^/]+)/?(.*)$’;
  if 'https://github.com/spitsh/spitsh'.match($regex) {
      .say for @/;
  }
  ```

## 0.0.13

- Added inline on blocks
```perl6
constant $foo = on {
    Debian { 'debian' }
    RHEL   { 'redhat'  }
};
```

## 0.0.12

- Fixed lots of String escaping bugs
- Added `rx{...}` Perl 6 like regex quote
- BusyBox is now its own OS
- Add Str.match, which matches against a regex and returns the match
  and any capture groups. This is very much a WIP, but this at least
  proves it's possible to return regex capture groups separately
  **without** using perl.
- add `.=` operator which works for calling methods and commands like:
  - `my File $tmp .= tmp;`
  - `my $foo = "foo"; $foo .= ${ sed "s/o/e/" };`

## 0.0.11

- for and while loops can be used as values like
  ```perl6
  my @a = for <one two three> { .uc }
  say @a eq <ONE TWO THREE> #-> True
  ```

## 0.0.10

- Added experimental .PRIMITIVE which returns the primitive type of the node
- Parameterized class comparisons `List[File] ~~ List[Str]` now give
  correct answer (True)
- if statements are now non-itemizing when used as a
  value. i.e. `${echo ("foo" if False)}` passes 0 arguments to echo
- Hugely improved error messages esp for "missing '}'" type syntax
  errors. They are still a WIP though.

## 0.0.9

- `when` now works even where $_ hasn't been declared
- A lot better inlining of if statements.
- You can now assign to control statements without putting them in ()
- Made variables in "" a bit smarter. It only uses ${curlies} when it needs to now.


## 0.0.8

- Great itemization refactor
  - `|` slip prefix is no longer a thing
  - Instead you have `@$foo` and `@(...)` to flatten things
  - `$@foo` and `$(...)` to itemize things
  - This is only relevant to `${...}` calls and `for` loops arguments
    for now as call arguments are always itemized.
  - `@self` now flattens right. It's still very experimental and is
    going to change a lot soon. I might make it so it's only available
    if your class inherits from List.
- lists as a single call argument is fixed. `foo(<one two three>)` used
  to be three arguments. Now it's one.

## 0.0.7

- Completely changed command syntax again. It's now much more terse.
  `${yum 'install','-y',$self ::>X}` => `${yum install -y $self *>X}`
  - commas removed
  - just `>` instead of `:>`
  - barewords instead of quoting on anything ~~ /[\w|'-']+/

## 0.0.6

- Added CHANGELOG.md ^_^
- `self` becomes `$self` and `@self` (no difference between the two yet)
- static methods must be labeled static like `static method foo() { ... }`
