use Test; plan 3;

{
    my $to-move = File.tmp;
    $to-move.write("win");
    my $dst = File.tmp;

    is $to-move.move-to($dst), $dst, '.move-to returns $self';
    is $dst.slurp, 'win', 'move-to overwites dst';
    nok $to-move, ‘moved file doesn't exist in original location’;
}
