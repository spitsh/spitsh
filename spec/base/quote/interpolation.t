use Test; plan 15;

{
    my $b = "foo bar";
    my @b = "foo bar";
    my @c = (foo => "bar");

    is "$b baz", "foo bar baz",'$ variable interpolation';
    is "@b baz", "foo bar baz", '@ variable interpolation';
    is "@b[0] baz", "foo bar baz", '@a[0] interpolation';
    is "@c<foo> baz", 'bar baz', '@a<foo> interpolation';
    is "@c{'foo'} baz", 'bar baz', ‘@a{'foo'} interpolation’;
    is “"$b" baz”, '"foo bar" baz','$ variable interpolation “”';
    is “"@b" baz”, '"foo bar" baz','@ variable interpolation “”';
    is ‘$b baz’, '$b baz', 'no $ variable interpolation ‘’';
    is '@b baz', "\@b baz", ‘no @ variable interpolatoin ''’;
    is ‘@b baz’, '@b baz', 'no @ variable interpolatoin ‘’';
    is "\$b baz", '$b baz', 'escape variable interpolation';
    is "\\$b baz", '\\foo bar baz','escape backslash before variable interpolation';
    is qq|$b baz|,"foo bar baz",'qq variable interpolation';
    is "${printf 'foo bar'} baz", 'foo bar baz', 'cmd interpolation';
    is qq|${printf 'foo bar'} baz|, 'foo bar baz', 'qq cmd interpolation';
}
