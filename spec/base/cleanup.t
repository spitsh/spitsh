use Test;

plan 2;

{
    my $cleanup1 = File<spit-cleanup-test1.txt>.cleanup;
    my $cleanup2 = File<spit-cleanup-test2.txt>.cleanup;
    .touch for $cleanup1, $cleanup2;
    ok $cleanup1 && $cleanup2, '.cleanup exists before';
    END {
        nok $cleanup1 && $cleanup2, '.cleanup was removed'
    };
}
