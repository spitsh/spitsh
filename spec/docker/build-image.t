use Test;

plan 14;


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
    my $b = Docker<img_build>;
    $b.create('alpine');

    constant File $foo = 'foo.txt';

    nok $b.exec( eval{$foo.exists} ), '.run check for non-existent file';
    ok  $b.exec( eval{$foo.touch} ),  '.run file touched';
    ok  $b.exec( eval{$foo.exists} ), '.run check file exists';

    my $img = $b.commit('run_test');

    $b.remove;

    ok $img.exists, '.commit means the image exists';

    ok $img.remove, '.remove a image that exists';
    nok $img.exists, '.exists after remove';
}

{
    my $anon = Docker.anon-create: "alpine";

    ok $anon, 'anon container created';
    $anon.remove;
    nok $anon, ‘anon doesn't exist after removed’;
}
