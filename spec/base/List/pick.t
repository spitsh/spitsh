use Test;

plan 3;

my @a = <one two three>;

my $pick = @a.pick;

for ^3 {
    ok @a.first(/^$pick$/), "$_. .pick'ed exists in orignal list";
}
