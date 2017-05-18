use Test; plan 12;

{
    my File $file .= tmp;
    for <foo bar baz> {
        $file.push($_);
    }

    ok $file.slurp.matches(/^foo\nbar\nbaz\n$/),".push in loop";
}

given File.tmp {
    .write: <one two three>;
    is .shift, 'one', '.shift return value';
    is .slurp, <two three>, '.shift modified file';
}

given File.tmp {
    .write: <one two three>;
    is .pop, 'three', '.pop return value';
    is .slurp, <one two>, '.pop modified file';
}

given File.tmp {
    .write: <one two three>;
    is .unshift("zero"), 'zero', '.unshift return value';
    is .slurp, <zero one two three>, '.unshift modified file';
}

given File.tmp {
    .write: <X.one two X.three four>;
    is .remove-lines(/^X\./), <X.one X.three>, '.remove-lines returns right value';
    is .slurp, <two four>, '.remove lines removed the right lines';
}

{
    my $str = "foood";
    given File.tmp {
        .write($str);
        .subst('o','e');
        is .slurp,"feood",".subst replaces first occurrence";
        .subst('o','e',:g);
        is .slurp,"feeed",".subst(:g), replaces all ocurrences";

        .write(<foo bar baz>);
        .subst("oo\nba","ood\n\nca");
        is .slurp,"food\n\ncar\nbaz",'.subst with \\n';
    }
}
