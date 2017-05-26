use Test;

plan 6;

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
{
    ok (~(loop (my $j = 0; $j < 5; $j++) { $j*$j })) ~~ List[Int],
       'loop return type is the correcy type of List';
}

{
    is ${printf '%s-%s-%s' (loop (my $k = 0; $k < 3; $k++) { $k*$k }) },
      '0-1-4', 'loop falttens in slurpy context';
}

{
    my @c = <1 2 3>;
    my Int @d = loop (my $l = 0; $l < 3; $l++) {
        $l, @c;
    }
    is @d, <0 1 2 3 1 1 2 3 2 1 2 3>, 'loop in List[Int] context';
}
