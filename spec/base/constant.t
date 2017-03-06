use Test;
plan 3;
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
