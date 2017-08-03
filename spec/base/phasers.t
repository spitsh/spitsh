use Test; plan 1;

is eval{ my $foo = "foo"; END { $foo.print }}.${sh}, 'foo',
  'basic END block';
