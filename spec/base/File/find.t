use Test; plan 10;

{
    my File $tmpdir .= tmp(:dir);
    ok $tmpdir.dir, 'tmp(:dir) returns a directory';

    my $child1 = $tmpdir.add('foo');
    is $child1, "$tmpdir/foo", '$child1.child';
    nok $child1, ‘.child doesn't cause directory to exist’;

    my $child2 = $child1.add('bar');
    is $child2, "$tmpdir/foo/bar", '$child2.child';

    $child2.mkdir.cd;

    ok $child2, 'child2 exists after .mkdir';
    ok $child1, 'child1 exists after .mkdir';
    is $child2, $?PWD, '.cd turns it into $?PWD';

    for <a b c> {
        my $top = $child2.add($_).mkdir;
        for <d e f> {
            my $under = $top.add($_).mkdir;
            for <g h i> {
                $under.add($_).touch; #ew
            }
        }
    }

    is $child2.find().elems, 3*3*3 + 3*3 + 3 + 1,
    '.find() found all files and directories';
    is $child2.find(name => /[ghi]$/).elems, 3*3*3,
    '.find(/../) found only those matching';

    CHECK-CLEAN nok $child2.exists, 'tmp(:dir) was cleaned up';
}
