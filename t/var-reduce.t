use Test;
use Spit::Compile;

plan 1;

nok compile(
    name => 'test if reduce',
    'my $foo = "foo"; say ("foo:$_" if $foo);'
) ~~ all(!*.contains('&&'), *.contains(':+')),
'if $var statements are reduced using ${var:+...}';
