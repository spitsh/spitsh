use Test;

plan 14;

{
    is 'foo'.JSON, '"foo"', '"foo".json';
    is "foo\nbar\n".JSON, '"foo\nbar\n"', '"foo\nbar\n".json';
    is "foo\nbar\nbaz".JSON, '"foo\nbar\nbaz"', '"foo\nbar\nbaz".json';
    is "hello\t\"world!".JSON, '"hello\t\"world!"', 'hello\t\"world!';
    is ''.JSON, '""', 'empty string';
    is <one two three>.JSON, '["one","two","three"]', '<one two three>';
    is ("hello\fworld\f!", "hello\tworld\t!").JSON, '["hello\fworld\f!","hello\tworld\t!"]',
      '("hello\fworld\f!","hello\tworld\t!")';

    is True.JSON, 'true', 'True';
    is False.JSON, 'false', 'False';
}

{
    my $a = "foo";
    my @b = <one two three>;

    my $json = { :$a, :@b };
    is $json, '{"a":"foo","b":["one","two","three"]}',
      'j{ $a, @b }';
}
{
    my JSON $json = {
        one => "two",
        three => <four five six>,
        four => {
            "seven" => "eight",
        }
    };

    is $json, '{"one":"two","three":["four","five","six"],"four":{"seven":"eight"}}',
      'nested json objects and array';
}

{
    is eval{ { :foo<bar> }.print }.${sh}, '{"foo":"bar"}', '.print';
}


{
    my $empty = { };
    ok $empty ~~ JSON, '{ } is an empty json object';
    is $empty, '{}', 'it is "{}"';
}
