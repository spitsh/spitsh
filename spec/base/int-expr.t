use Test;

plan 42;

{
   my Int $a;
   is $a + $a,0,'unintialized Int defaults to 0';
}
{
    my $a = 2;
    my $b = 1;

    is 1 + 2, 3,'basic addition';
    is $a + $b, 3,"basic addition (var)";
    is 2 - 1,1, 'basic substraction';
    is $a - $b,1,"basic subtraction (var)";
}

{
    my $x = 3;
    my $y = -5;
    my $z = 0;
    is 3 + -5,-2, 'addition with negative rhs';
    is $x + $y, -2,'addition with negative rhs (var)';
    is 3 - -5,8,'substraction with negative rhs';
    is $x - $y,8,'substraction with negative rhs (var)';
}

{
    my $x = 3;
    my $y = 5;
    is 3 * 5  ,15,'multiplication';
    is $x * $y,15,'multiplication (var)';
    is -3 * -5,15,'multiplication neg rhs & lhs';
    is -$x * -$y,15,  'multiplication neg rhs & lhs (var)';
    is -3 * 5,-15,    'multiplication neg lhs';
    is -$x * $y,-15,  'multiplication neg lhs (var)';
    is 3 * -5,-15,    'multiplication neg lhs';
    is $x * -$y,-15,  'multiplication neg lhs (var)';
}

{
    my $x = 3;
    my $y = 5;
    my $z = 0;
    is 0 - (3 + 5),-8,'multiplication parens';
    is $z - ($x + $y),-8,'multiplication parens (var)';
}

{
    my $d = 1;
    $d += 3;
    is $d,4,'+=';
    $d -= 3;
    is $d,1,'-=';
}

{
    my Int $i = 0;
    is ++$i,1,"pre-increment";
    is --$i,0,"pre-decrement";
}

{
    my $i = 0;
    is $i++,0,"post-increment doesn't immediately incrememnt";
    is $i,1,"post-inrement increments";
    is $i--,1,"post-decrement doesn't immediately decrement";
    is $i,0,"post-decrement decrements";
}

{
    sub +mul(Int $x,Int $y) { $x * $y }
    sub +sum(Int $x,Int $y) { $x + $y }
    sub +subt(Int $x,Int $y) { $x - $y }

    is sum(3,5),8,'+ as return value';
    is subt(3,5),-2,'- as return value';
    is mul(3,5),15,'* as return value';
}

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
