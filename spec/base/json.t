use Test;

plan 11;

{
    is 'foo'.JSON, '"foo"', '"foo".json';
    is "foo\nbar\n".JSON, '"foo\nbar\n"', '"foo\nbar\n".json';
    is "hello\t\"world!".JSON, '"hello\t\"world!"', 'hello\t\"world!';
    is ''.JSON, '""', 'empty string';
    is <one two three>.JSON, '["one","two","three"]', '<one two three>';
    is ("hello\fworld", "hello\tworld").JSON, '["hello\fworld","hello\tworld"]',
    '("hello\fworld","hello\tworld")';

    is True.JSON, 'true', 'True';
    is False.JSON, 'false', 'False';
}

{
    my $json = j{ one => "two", three => ("four","five") };

    is $json<one>.unescape, 'two', '$json<one>';
    is $json<three>.flatten, <four five>, '$json<three> (array)';
    is $json<three>[1].unescape, 'five', '$json<three>[1]';
}
