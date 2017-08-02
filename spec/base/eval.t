use Test;

plan 14;

{
    my $foo = "foo";

    ok eval{ $foo eq "foo" }.${sh}, 'cmp as single statement (True)';
    nok eval{ $foo eq "bar" }.${sh}, 'cmp as single statement (False)';
}

{
    constant $os = Alpine;

    is eval(:$os){ say $:os.name }.${sh}, 'Alpine', 'can use a constant as a eval option';
}

{
    is eval(foo => "bar"){
        print eval{ my $:foo; print $:foo }.${sh};
    }.${sh}, 'bar', 'options get passed into inner evals';

    is eval(foo => "bar"){
        print eval(foo => 'baz'){ my $:foo; print $:foo }.${sh};
    }.${sh}, 'baz', 'options can be overridden by inner evals';
}

{
    my $foo = "bar";
    is eval(:$foo){ constant $:foo; print $:foo }.${sh}, 'bar',
      'runtime argument';
}

{
    sub foo()~ { ${printf "baz"} }
    is eval(foo => foo()){ constant $:foo; print $:foo }.${sh}, 'baz',
        'inlinable sub call as runtime argument';

}

{
    my $one = Str.random(1); my $two = Str.random(1);
    my $three = Str.random(1); my $four = Str.random(1);
    my $five = Str.random(1);
    is eval(:$one, :$two, :$three, :$four,:$five) {
        my $:one; my $:two; my $:three; my $:four; my $:five;
        say "$:one$:two$:three$:four$:five";
    }.${sh},
    "$one$two$three$four$five", 'many eval options';

    is eval(:$one, :$two, :$three, :$four,:$five) {
        say "$:<one>$:<two>$:<three>$:<four>$:<five>";
    }.${sh},
    "$one$two$three$four$five", 'many eval options using indirect lookup';

    is eval{ say "$one$two$three$four$five" }.${sh}, "$one$two$three$four$five",
    'many outer lexical references';

}


{
    my $foo = "bar";
    is eval(:$foo){ my $:foo; print $:foo }.${sh}, eval(:$foo){ my $:foo; print $:foo }.${sh},
      'two evals in the same statement';
}

{
    my $thing = Str.random;

    is eval(:$thing){
        say $:<thing>;
        eval(){ say $:<thing> }.${sh};
    }.${sh}, ($thing,$thing), 'nested eval with option';


    is eval{
        say $thing;
        eval{ say $thing; }.${sh};
    }.${sh}, ($thing,$thing), 'nested eval with outer reference';
}

{
    my $crazy  = Str.random(5) ~ "'" ~ Str.random(4);
    is eval{ say $crazy }.${sh}, $crazy, ‘single ' in outer reference’;
}
