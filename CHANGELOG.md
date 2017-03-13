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
