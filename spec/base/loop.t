use Test;

plan 3;

{
    my @a;
    loop (my $i = 0; $i < 5; $i++) {
        @a.push($i);
    }

    is @a, <0 1 2 3 4>, 'my $i = 0; $i < 5; $i++';
    is $i, 5, '$i == 5';
}


{
    my Int @b = loop (my $j = 0; $j < 5; $j++) { $j*$j }

    is @b, <0 1 4 9 16>, 'loop as a value';
}
