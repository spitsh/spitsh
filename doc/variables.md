# $*os
 The operating system the script is being compiled for. This isn't the OS the script is running on (There is currently no way of knowing that). It is always known at script composition time. So a script like this:
```perl6
given $*os {
    say "I wonder what kind of OS I'm on...?";
    when Debian {
        say "It's some kind of Debian:";
        say (
            when Ubuntu { "It's some other kind of Ubuntu XD"}
            default { "nope just plain ol Debian!" }
        )
    }
    when RHEL   { say "Redhat!"}
    when BSD { say "oooh a BSD" }
}
``` 
Will be optimized down to something like this:
```perl6
say "I wonder what kind of OS I'm on...?"
say "It's some kind of Debian:"
say "It's some other kind of Ubuntu XD"
```
# $IFS
 The internal field separator. For Spit it's always `\n`.
# $?CAP
 File descriptor used to represent the STDOUT of a cmd inside the script rather than the script itself. '~' is a short alias for `$?CAP` in `${..}` commands.
```perl6
# captures both the STDOUT and STDERR of ls into $res
my $res = ${ls /etc '/I/dont/exist' *>~};
say "ls returned $res";
```
# $*NULL
 File descriptor redirected to '/dev/null' by default. 'X' is a short alias for `$*NULL` in `${..}` commands.
```perl6
if ${command -v perl >X} {
    say "perl exists";
}
```
# $*OUT
 File descriptor connected to the STDOUT of the script by default.
```perl6
 $*OUT.write("hello world") # same as print("hello world")
```
# $*ERR
 File descriptor connected to the STDERR of the script.  '!' is a short alias for `$*ERR` in `${..}` commands.
```perl6
$*ERR.write("something to script's stderr");
${printf "allo earth" > $*ERR};
${printf "allo earth" >!}; #shorthand
${ls '/I/dont/exist' !> $*OUT}; #redirect STDERR to script's STDOUT
my $error = ${ls '/I/dont/exist' !>~}; # capture STDERR into return value of cmd
```
# @/
 The match list variable. Like `$/` in Perl 6 it stores the what was match after a something is matched against a regex.
```perl6
my $text = "The file is: foo.txt";
$text.match(/:\s*(.+)\.(.+)$/);
say @/[0]; #-> : foo.txt
say @/[1]; #-> foo
say @/[2]; #-> txt
```
