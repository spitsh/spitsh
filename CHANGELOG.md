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
