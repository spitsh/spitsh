use Test;

plan 12;


{
    my $b = Docker<spit_img_build>;
    Docker.create('alpine', name => $b);

    constant File $foo = 'foo.txt';

    nok $b.exec( eval{$foo.exists} ), '.run check for non-existent file';
    ok  $b.exec( eval{$foo.touch} ),  '.run file touched';
    ok  $b.exec( eval{$foo.exists} ), '.run check file exists';

    my $img = $b.commit(name => 'run_test');

    $b.remove;

    ok $img.exists, '.commit means the image exists';
    ok $img,        'DockerImg.Bool means .exists (true)';
    {
        my $tagged = $img.add-tag('goof');
        is $tagged, 'run_test:goof', 'tag returned what it was given';
        ok $tagged, 'tagged image exists';
        ok $tagged.remove, 'tagged image removed';
        ok $img, ‘removing tagged image doesn't remove original’;
    }
    ok $img.remove, '.remove a image that exists';
    nok $img.exists, '.exists after remove';
    nok $img,        'DockerImg.Bool means .exists (false)';
}
