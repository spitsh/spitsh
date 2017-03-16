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
