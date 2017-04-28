use Test;

plan 2;

my $foo = "foo";

ok eval{ $foo eq "foo" }.${sh}, 'cmp as single statement (True)';
nok eval{ $foo eq "bar" }.${sh}, 'cmp as single statement (False)';
