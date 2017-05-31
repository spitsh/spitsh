use Test;

plan 3;
{
    my $one = { :id(0), :val("q")};
    my $two = { :id(1), :val("a")};
    my $three = { :id(2), :val("z") };
    my JSON @a = $one, $two, $three;
    my @b = @a.sort("val");
    is @b[0], $two, '.sort first correct';
    is @b[1], $one, '.sort second correct';
    is @b[2], $three, '.sort third correct';
}
