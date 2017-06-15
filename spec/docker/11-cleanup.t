use Test;

plan 2;

{
    my $tmp1 = Docker.create("alpine").cleanup;
    my $tmp2 = Docker.create("alpine").cleanup;
    ok $tmp1 && $tmp2, 'containers created';

    CHECK-CLEAN nok $tmp1 && $tmp2, 'END .cleanup containers destroyed';
}
