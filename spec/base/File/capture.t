use Test;
plan 2;
{
    # intentionally with indenting whitespace
    given File.tmp {
        .write: ‘bar: foo
                foo: bar
                baz: foo
                bar: baz’;


        is .capture(/bar: (.*)/), 'foo', '.capture with target on first line';
        is .capture(/foo: (.*)/), 'bar', '.capture with target on second line';
    }
}
