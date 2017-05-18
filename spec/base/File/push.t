use Test; plan 1;

{
    my File $file .= tmp;
    for <foo bar baz> {
        $file.push($_);
    }

    ok $file.slurp.matches(/^foo\nbar\nbaz\n$/),".push in loop";
}
