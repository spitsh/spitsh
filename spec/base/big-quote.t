# tests for quotes with lots of blocks inside them

use Test; plan 2;

my @a = <one two three>;
my $quote =
qq(foo

{ ($_ for @a).join(',') }

bar);

is $quote,
'foo

one,two,three

bar', ‘block doesn't eat whitespace’;

#-------

my $foo = True;
my $bar = True;

my $quote2 =

qq(
{  $bar && 'bar' }

---
{ 'foo' if $foo }
);

is $quote2,
'
bar

---
foo
', 'two quoted blocks';
