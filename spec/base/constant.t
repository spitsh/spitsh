use Test;
plan 5;

{
    constant $x = "foo";
    is $x,'foo','basic constant';
}

{
    sub ~foo { "bar" }
    constant $x = foo;
    is $x,'bar','constant assigned to a sub call';
}

{
    constant Str $x = 1;
    nok $x ~~ Int,'value of constant loses type when assigned';
}

{
    constant $x = ${printf '%s' 'foo'},"bar";
    is $x,<foo bar>,'assignment to list with runtime value';
}

{
    constant $x = if ${true} {
        "foo"
    } else {
        "bar";
    };
    is $x,"foo",'assignment to bare if';
}
