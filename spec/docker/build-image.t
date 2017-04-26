use Test;

plan 9;


{
    my $a = Docker<create_test>;

    nok $a, ‘.Bool before created’;
    ok $a.create('alpine'), '.create';
    ok $a, '.Bool after created';
    ok $a.exists, '.exists';
    ok $a.remove, '.remove';
        nok $a, '.Bool after removed';
}

{
    my $b = Docker<run_test>;
    $b.create('alpine');

    constant File $foo = 'foo.txt';

    nok $b.run( eval{$foo.exists} ), '.run check for non-existent file';
    ok  $b.run( eval{$foo.touch} ),  '.run file touched';
    ok  $b.run( eval{$foo.exists} ), '.run check file exists';

    $b.remove;
}
