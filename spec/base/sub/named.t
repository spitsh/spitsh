use Test; plan 11;
{
    my $syntax;
    sub alpha(:$a,:$b) {
        is $a,"foo3","named $a has correct value ($syntax)";
        is $b,"bar3","named $b has correct value ($syntax)";
    }

    $syntax = ':<..>';
    alpha(:a<foo3>,:b("bar3"));
    $syntax = '=>';
    alpha(a => "foo3",b => "bar3");
    $syntax = '=> A ~ B';
    my $foo = "foo";
    my $bar = "bar";
    alpha(a => $foo ~ 3,b => $bar ~ 3 );

}

{
    sub beta(:$a,:$b,$c) {
        is $a,"foo4","named $a with pos";
        is $b,"bar4","named $b with pos";
        is $c,"baz1","pos $c with named works";
    }

    beta :a<foo4>,"baz1",:b<bar4>;
}


{
    sub gamma(Bool :$a = True)~ { $a.gist }
    is gamma, 'True', 'named default true';
    is gamma(:!a), 'False', ':!a overrides default';
}
