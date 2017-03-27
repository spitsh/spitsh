use Test;

plan 7;
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
