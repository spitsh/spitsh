use Test; plan 3;

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
