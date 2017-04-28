use Test;

plan 3;

{
    my $foo = "foo";

    ok eval{ $foo eq "foo" }.${sh}, 'cmp as single statement (True)';
    nok eval{ $foo eq "bar" }.${sh}, 'cmp as single statement (False)';
}

{
    constant $os = Alpine;

    is eval(:$os){ say $*os }.${sh}, 'Alpine', 'can use a constant as a eval option';
}
