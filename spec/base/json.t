use Test;

plan 8;

is 'foo'.JSON, '"foo"', '"foo".json';
is "foo\nbar\n".JSON, '"foo\nbar\n"', '"foo\nbar\n".json';
is "hello\t\"world!".JSON, '"hello\t\"world!"', 'hello\t\"world!';
is ''.JSON, '""', 'empty string';
is <one two three>.JSON, '["one","two","three"]', '<one two three>';
is ("hello\fworld", "hello\tworld").JSON, '["hello\fworld","hello\tworld"]',
  '("hello\fworld","hello\tworld")';

is True.JSON, 'true', 'True';
is False.JSON, 'false', 'False';
