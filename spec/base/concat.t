use Test;

plan 2;
{
    my $a = "foo";
    my $b = "bar";
    my $c = "baz";
    is $a ~ ' ' ~ $b ~ $c,'foo barbaz',"concat";
}

{

    my $a = "foo";
    $a ~= " bar";
    is $a,"foo bar","~=";
}
