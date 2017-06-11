use Test;
plan 2;
{
    # intentionally with indenting whitespace
    my $str=‘bar: foo
             foo: bar
             baz: foo
             bar: baz’;

    is $str.capture(/bar: (.*)/), 'foo', '.capture with target on first line';
    is $str.capture(/foo: (.*)/), 'bar', '.capture with target on second line';
}
