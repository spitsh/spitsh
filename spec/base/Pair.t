use Test;

plan 10;

{
    my $a = one => "two";

    is $a.key, 'one', '.key';
    is $a.value, 'two', '.value';

    $a = "three" => "four";
    is $a.key, 'three', '"three" => "four" .key';
    is $a.value, 'four', '"three" => "four" .value';
}

{
    my $b = one => two => 3;
    is $b.key, 'one', 'one => two => 3 .key';
    is $b.value, (two => 3), 'one => two => 3 .value';
    is $b.value.WHAT, Pair[Str, Int], 'one => two => 3 .value';
    is $b.value.value, 3, 'one => two => 3 .value.value';
    is $b.value.value.WHAT, Int, 'one => two => 3 .value.value.WHAT';
}

{
    sub ~paired(Pair $p) { $p.value }
    is paired((foo => "bar")), "bar", 'pair can be used as positional argument';
}
