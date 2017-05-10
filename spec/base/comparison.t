use Test;

plan 48;

{
    ok 5 > 3, '5 > 3';
    nok 5 > 5, '! 5 > 5';
    nok 3 > 5, '! 3 > 5';
    ok 2 < 3, '2 < 3';
    nok 3 < 2, '! 3 < 2';
    nok 3 < 3, '! 3 < 3';
    ok 3 >= 3, '3 >= 3';
    ok 3 >= 2, '3 >= 2';
    nok 2 >= 3, '! 2>= 3';
    ok 3 <= 3, '3 <= 3';
    ok 2 <= 3, '2 <= 3';
    nok 3 <= 2, '! 3<= 2';
}


{
    my $five = 5;
    my $three = 3;
    my $two = 2;
    ok $five > $three, '$five > $three';
    nok $five > $five, '! $five > $five';
    nok $three > $five, '! $three > $five';
    ok $two < $three, '$two < $three';
    nok $three < $two, '! $three < $two';
    nok $three < $three, '! $three < $three';
    ok $three >= $three, '$three >= $three';
    ok $three >= $two, '$three >= $two';
    nok $two >= $three, '! $two>= $three';
    ok $three <= $three, '$three <= $three';
    ok $two <= $three, '$two <= $three';
    nok $three <= $two, '! $three<= $two';
}

{
    ok "abc" lt "abz", 'abc lt abz';
    nok "abz" lt "abc", '! abz lt abc';
    nok "abc" lt "abc", '! abc lt abc';

    ok "abz" gt "abc", 'abz gt abc';
    nok "abz" gt "abz", '! abz gt abz';
    nok "abc" gt "abz", '! abc gt abz';

    nok "abc" ge "abz", '! abc ge abz';
    ok "abz" ge "abz", 'abz ge abz';
    ok "abz" ge "abc", 'abz ge abc';

    nok "abz" le "abc", "! abz le abc";
    ok "abc" le "abc", 'abc le abc';
    ok "abc" le "abz", 'abc le abz';

}


{
    my $abc = "abc";
    my $abz = "abz";

    ok $abc lt $abz, '$abc lt $abz';
    nok $abz lt $abc, '! $abz lt $abc';
    nok $abc lt $abc, '! $abc lt $abc';

    ok $abz gt $abc, '$abz gt $abc';
    nok $abz gt $abz, '! $abz gt $abz';
    nok $abc gt $abz, '! $abc gt $abz';

    nok $abc ge $abz, '! $abc ge $abz';
    ok $abz ge $abz, '$abz ge $abz';
    ok $abz ge $abc, '$abz ge $abc';

    nok $abz le $abc, "! $abz le $abc";
    ok $abc le $abc, '$abc le $abc';
    ok $abc le $abz, '$abc le $abz';
}
