# Str
 The Str class is the base primitive class of Spit-sh. It represents a string in the shell. Since all shell constructs are made out of strings all types inherits from this class.
```perl6
say "foo" ~~ Str; # true
say <one two three> ~~ Str; #true
```
## Bool
>method Bool( ⟶ [Bool](./Bool.md))


 Returns true if the string isn't empty
## bytes
>method bytes( ⟶ [Int](./Int.md))


 Returns the number of bytes in the string.
## chars
>method chars( ⟶ [Int](./Int.md))


 Returns the number of characters in the string. **note:** This will depend on the locale of the terminal the script is running in.
## contains
>method contains([Str](./Str.md) **$needle**, [Bool](./Bool.md) **:$i** ⟶ [Bool](./Bool.md))


 Returns true if the string contains `$needle`.
```perl6
say "Hello, World".contains('Wo'); #-> True
say "Hello, World".contains('wo'); #-> False
say "Hello, World".contains('wo',:i); #-> True
```

|Parameter|Description|
|---------|-----------|
|**$needle**| The string being searched for|
|**:$i**| Turns on case insensitive matching|
## ends-with
>method ends-with([Str](./Str.md) **$ends-with** ⟶ [Bool](./Bool.md))


 Returns true if the string ends with the argument.
```perl6
my @urls = <github.com ftp://ftp.FreeBSD.org>;
for @urls {
    print "$_ might be: ";
    when .ends-with('.com') { say 'commercial' }
    when .ends-with('.org') { say 'an organisation' }
    when .ends-with('.io')  { say 'a moon of Jupiter' }
}
```

|Parameter|Description|
|---------|-----------|
|**$ends-with**| True if the string ends-with this|
## gist
>method gist( ⟶ [Str](./Str.md))


## lc
>method lc( ⟶ [Str](./Str.md))


 Returns an lowercase version of the string
## match
>method match([Regex](./Regex.md) **$r** ⟶ [Bool](./Bool.md))


 Returns true if the the string matches the regex and sets the `@/` match variable to the match and its capture groups (one per line).
```perl6
my $regex = rx‘^(.+)://([^/]+)/?(.*)$’;
if 'https://github.com/spitsh/spitsh'.match($regex) {
    say @/[0]; #-> https://github.com/spitsh/spitsh
    say @/[1]; #-> https
    say @/[2]; #-> github.com
    say @/[3]; #-> spitsh/spitsh
}
```

|Parameter|Description|
|---------|-----------|
|**$r**| The regular expression to match against|
## note
>method note()


 Prints the string to stderr
## say
>method say()


 Prints the string to stdout
## split
>method split([Str](./Str.md) **$sep** ⟶ [List](./List.md))


 Splits the string on a separator. Returns the string with each instance of the `$sep` replaced with `\n` as a [List].

|Parameter|Description|
|---------|-----------|
|**$sep**| The separator to split on|
## starts-with
>method starts-with([Str](./Str.md) **$starts-with** ⟶ [Bool](./Bool.md))


 Returns true if the string starts with the argument.
```perl6
my @urls = <http://github.com ftp://ftp.FreeBSD.org>;
for @urls {
    print "$_ is:";
    when .starts-with('http') { say "hyper text transfer" }
    when .starts-with('ftp')  { say "file transfer" }
    default { "well I'm not sure.." }
}
```

|Parameter|Description|
|---------|-----------|
|**$starts-with**| True if the string starts-with this|
## subst
>method subst([Str](./Str.md) **$target**, [Str](./Str.md) **$replacement**, [Bool](./Bool.md) **:$g** ⟶ [Str](./Str.md))


 Returns the string with the target string replaced by a replacement string. Does not modify the original string.
```perl6
my $a = "food";
$a.subst('o','e').say;
$a.subst('o','e',:g).say;
say $a;
```

|Parameter|Description|
|---------|-----------|
|**$target**| The string to be replaced|
|**$replacement**| The string to replace it with|
|**:$g**| Turns on global matching|
## uc
>method uc( ⟶ [Str](./Str.md))


 Returns an uppercase version of the string
