use Test;
plan 11;

{
    my $str = "food";
    is $str.subst('o','e'),"feod",".subst replaces first occurrence";
    is $str.subst('o','e',:g),"feed",'.subst(:g), replaces all ocurrences';
}

{
    # use a carat because we use RS=^$ which won't work everywhere.
    my $nl-str = "foo\n^bar\nbaz";
    is $nl-str.subst("oo\n^ba","ood\n\nca"),"food\n\ncar\nbaz",'.subst with \\n';
}

{
    my $a = "aaZaa";
    is $a.subst("a","aa"), 'aaaZaa', 'relpace a with aa';
    is $a.subst("a", "aa", :g), 'aaaaZaaaa', 'replace a with aa :g';
    is $a.subst("aa", "a", :g), 'aZa', 'replace aa with a :g';
}

{
    my $b = '12341234';
    is $b.subst('12','', :g), '3434', 'replace 2 chars with 0';
    is $b.subst('123','', :g), '44', 'replace 3 chars with 0';
    is $b.subst('123','6', :g), '6464','replace 3 chars with 1';
    is $b.subst('34','', :g), '1212', 'replace 2 chars with "" not at the start';
}

{
    is "xXXxX".subst("xX","x",:g), 'xXx', 'implementation mistake';
}
