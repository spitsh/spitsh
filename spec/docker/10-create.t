use Test;

plan 5;

{
    my $a = Docker<spit_create_test>;

    nok $a, ‘.Bool before created’;
    Docker.create('alpine', name => $a), '.create';
    ok $a, '.Bool after created';
    ok $a.exists, '.exists';
    ok $a.remove, '.remove';
    nok $a, '.Bool after removed';
}
