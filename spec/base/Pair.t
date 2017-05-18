use Test;

plan 39;

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


{
    my @a = one => 1,
            two => 2,
            three => 3;


    ok @a ~~ List[Pair[Str,Int]], '@a ~~ List[Str,Int]';
    is @a[0], (one => 1), '@a[0]';
    is @a[1], (two => 2), '@a[1]';
    ok @a<two> ~~ Int, '@a<one> ~~ Int';
    is @a<two>, 2, '@a<two>';
    is @a<two> + @a<one>, @a<three>, '@a<two> + @<one>';

    is @a.keys, <one two three>, '.keys';
    ok @a.keys ~~ List[Str], '.keys ~~ List[Str]';
    is @a.values, <1 2 3>, '.values';
    ok @a.values ~~ List[Int], '.values ~~ List[Int]';
    is @a.values.WHAT, 'List[Int]','.values.WHAT';

    # Can't get JSON right until it's implemented as a macro so
    # Int type is preserved
    is ('{' ~ (.key.JSON ~ ':' ~ .value.JSON  for @a).join(',') ~ '}'),
      '{"one":1,"two":2,"three":3}', 'TEMP: manual JSON';

    @a<four> = 4;
    is @a<four>, 4, '@a<four> = 4';
    is @a.keys, <one two three four>, ‘four in list after it's been added’;

    ok @a.exists-key("one"), '.exists-key';
    @a.delete-key('one');
    is @a<one>, False, '.delete-key("one")';
    nok @a.exists-key("one"), '.exists-key False after removed';
    is @a.keys, <two three four>, ‘one not in list after it's been removed’;

    @a.delete-key('three');
    is @a<three>, False, ‘three not in list after it's been removed’;
    is @a.keys, <two four>, 'only two and for left';
}

{
    given one => "two" {
        is .JSON, '{"one":"two"}', 'Pair.JSON';
    }
}

{
    my @b = Australia => 'Canberra',
            France    => 'Paris',
            Uganda  => 'Kampala';

    is @b.JSON, '{"Australia":"Canberra","France":"Paris","Uganda":"Kampala"}',
      'List[Pair].JSON';
}

{
    my @c = one => two => "three",
            four => five => "six";

    is @c.keys, <one four>, '.keys, list of Pair of Pairs';
    is @c.values, (two => "three", five => "six"),
      '.values, list of Pair of Pairs';
}

{
    my Pair @start-empty;

    @start-empty<%foo> = '%bar';
    @start-empty{"🆆🅴🅸🆁🅳"} = "🅥🅐🆘";

    is @start-empty<%foo>, '%bar', '% works in keys';
    is @start-empty[0].key, '%foo', ‘% doesn't screw up .key’;
    is @start-empty[0].value,'%bar', ‘% doesn't screw up .value’;
    is @start-empty[1].key, "🆆🅴🅸🆁🅳", ‘unicode doesn't break .key’;
    is @start-empty[1].value, "🅥🅐🆘", ‘unicode doesn't break .value’;
}
