use Test;

plan 2;

{
    my $tmp1 = Docker.tmp: "alpine";
    my $tmp2 = Docker.tmp: "alpine";
    ok $tmp1 && $tmp2, 'containers created';

    CHECK-CLEAN nok $tmp1 && $tmp2, 'END anon containers destroyed';
}
