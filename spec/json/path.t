use Test; plan 3;

{
    my $json = j{ one => "two", three => ("four","five") };

    is $json<one>.unescape, 'two', '$json<one>';
    is $json<three>.flatten, <four five>, '$json<three> (array)';
    is $json<three>[1].unescape, 'five', '$json<three>[1]';
}
