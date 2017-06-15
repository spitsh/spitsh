use Test; plan 2;

{
    my $dir = File.tmp(:dir);
    $dir.cd;
    is $?PWD, $dir, '.cd';
}

{
    my $dir = File.tmp(:dir);
    cd $dir;
    is $?PWD, $dir, '.cd';
}
