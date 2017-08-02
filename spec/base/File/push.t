use Test; plan 3;

{
    my File $file .= tmp;
    for <foo bar baz> {
        $file.push($_);
    }

    ok $file.slurp.matches(/^foo\nbar\nbaz\n$/),".push in loop";
}

{
    given File.tmp {
        .remove;
        is .push('foo'), $_, '.push returns the invocant file';
        is .slurp, 'foo', '.push onto non-existing file';
    }
}
