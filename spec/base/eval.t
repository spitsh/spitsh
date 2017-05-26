use Test;

plan 6;

{
    my $foo = "foo";

    ok eval{ $foo eq "foo" }.${sh}, 'cmp as single statement (True)';
    nok eval{ $foo eq "bar" }.${sh}, 'cmp as single statement (False)';
}

{
    constant $os = Alpine;

    is eval(:$os){ say $*os.name }.${sh}, 'Alpine', 'can use a constant as a eval option';
}

{
    my $foo = "bar";
    is eval(:$foo){ constant $*foo; print $*foo }.${sh}, 'bar',
      'runtime argument';
}

{
    my $one = 1; my $two = 2; my $three = 3; my $four = 4; my $five = 5;
    is eval(:$one, :$two, :$three, :$four,:$five) {
        my $*one; my $*two; my $*three; my $*four; my $*five;
        say "$*one$*two$*three$*four$*five";
    }.${sh},
    '12345', 'many eval options';
}


{
    my $foo = "bar";
    is eval(:$foo){ my $*foo; print $*foo }.${sh}, eval(:$foo){ my $*foo; print $*foo }.${sh},
      'two evals in the same statement';
}
