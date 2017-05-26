use Test;
plan 5;

{
    my $str = "f.oo*b?ar";
    ok $str.starts-with("f.oo"),'starts-with';
    nok $str.starts-with("*f.oo"),'!starts-with';
    ok $str.ends-with("b?ar"),'ends-with';
    nok $str.ends-with("oar"),'!ends-with';
}

{
    my $str = "some\c[GHOST]\c[SPIRAL SHELL]spooks\c[GHOST]\c[SPIRAL SHELL]";
    ok $str.ends-with("\c[GHOST]\c[SPIRAL SHELL]"),
      '.ends-with with multiple occurrences of the target string';
}
