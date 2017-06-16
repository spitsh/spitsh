use Test; plan 14;

{
    my $a = {};
    $a<foo> = "bar";
    is $a<foo>, "bar", '$j<foo> = "bar"';
    $a<foo> = "baz";
    is $a<foo>, "baz", '$j<foo> = "baz"';
    is +$a.keys, 1, 'still only has 1 key';
}

{
    my $b = {};
    $b{'\"le quotes"'} = ｢\"le quoted" value｣;
    is $b{'\"le quotes"'}, ｢\"le quoted" value｣, 'quoting value';
}

{
    my $c = {};
    my $key = '\"le quotes"';
    my $value = ｢\"le quoted" value｣;
    $c{$key} = $value;
    is $c{$key}, $value, 'quoting value (runtime)';
}

{
    my $d = {};

    $d<one> = {
        two => "three"
    };
    is $d, '{"one":{"two":"three"}}', '= { ... }';
    $d<four> = ["five", "six", "seven"];
    is $d<four>,'["five","six","seven"]', ' = [...]';
}

{
    my $e = {};
    my $crazy-key = "I\rm\fcrazy\n\n";
    my $crazy-value = "foo\nbar\t\bbaz\f\fbo\rked";
    $e{$crazy-key} = $crazy-value;
    is $e{$crazy-key}, $crazy-value, 'control characters in key and value';
}

{
    my $f = [];
    $f[0] = "foo";
    is $f, '["foo"]', '$j[0] = "foo"';
    is $f[0], 'foo', '$j[0] has right value';
    $f[2] = "baz";
    is $f, '["foo",null,"baz"]', '$j[2] = "baz"';
    $f[3]<auto> = "win";
    is $f[3]<auto>, 'win', 'auto-vivify object in array';
}

{
    my $g = { foo => { }, };
    my $bar = "BAR";
    $g<foo>{$bar.lc}<baz> = { "berz" => "win" };
    is $g<foo>{$bar.lc}<baz><berz>, "win", '<foo>{"BAR".lc}<baz> = "win"';

    $g<auto><snorto>[2] = "win";
    is $g<auto><snorto>[2], 'win', 'auto-vivify array inside object';
}
