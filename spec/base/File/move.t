use Test; plan 2;

{
    my $to-move = File.tmp;
    $to-move.write("win");
    my $dst = File.tmp;

    $to-move.move-to($dst);
    is $dst.slurp, 'win', 'move-to overwites dst';
    nok $to-move, ‘moved file doesn't exist in original location’;
}
