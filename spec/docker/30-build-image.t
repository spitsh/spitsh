use Test;

plan 8;


{
    my $b = Docker<spit_img_build>;
    Docker.create('alpine', name => $b);

    constant File $foo = 'foo.txt';

    nok $b.exec( eval{$foo.exists} ), '.run check for non-existent file';
    ok  $b.exec( eval{$foo.touch} ),  '.run file touched';
    ok  $b.exec( eval{$foo.exists} ), '.run check file exists';

    my $img = $b.commit('run_test');

    $b.remove;

    ok $img.exists, '.commit means the image exists';
    ok $img,        'DockerImg.Bool means .exists (true)';
    ok $img.remove, '.remove a image that exists';
    nok $img.exists, '.exists after remove';
    nok $img,        'DockerImg.Bool means .exists (false)';
}
