use Test; plan 1;

eval{ my $foo = "foo"; END{ $foo.print }}.${sh}, 'foo',
  'basic END block';
