use Test;

plan 6;

{

    my $str = "foobar";
    is($str.substr(0, 0), '', 'Empty string with 0 as thrid arg');
    is($str.substr(3, 0), '', 'Empty string with 0 as thrid arg');
    is($str.substr(0, 1), "f", "first char");
    is($str.substr(1, 2), "oo", "arbitrary middle");
    is($str.substr(3,100), "bar", "length omitted");
    is($str.substr(3, 10), "bar", "length goes past end");
}
