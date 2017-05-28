use Test;

plan 3;

my @a = <one two three>;

for ^3 {
    my $pick = @a.pick;
    ok @a.first(/^$pick$/), "$_. .pick'ed exists in orignal list";
}
