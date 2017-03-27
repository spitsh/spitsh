use Test;

plan 10;
my $a;
$a = "init";
{
    my $a = "foo bar";
    is $a,"foo bar","basic assignment works";
}
is $a,"init","lexical scope works";
{
    my $a = True;
    ok $a,"assingment to True";
}

{
    my $a = False;
    nok $a,"assignment to False";
}

{
    my $foo-bar = "foo";
    is $foo-bar,"foo","kebab var works";
}

{
    (my $foo = "derp") = "bar";
    is $foo,"bar","decl inside parens works";
}

{
    my Str $i = 1;
    is $i,"1","can override type";
}

{
    my File $tmp .= tmp;
    ok $tmp.exists, 'my File $tmp .= tmp';

    my $str = "foo";
    $str .= subst('o','e',:g);
    is $str, 'fee', '$str .= ...';

    $str .= ${sed 's/e/E/g' };
    is $str, 'fEE', '.= ${ ... }';
}
