use Test;

plan 2;

{
    sub foo($a?)~ { $a || "bar" }
    is foo(), "bar", 'can call without optional parameter';
    is foo("foo"), "foo", 'passing optional parameter works';
}
