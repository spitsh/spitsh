use Test; plan 2;

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
        .push('foo');
        is .slurp, 'foo', '.push onto non-existing file';
    }
}
