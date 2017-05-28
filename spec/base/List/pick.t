use Test;

plan 3;

my @a = <one two three>;

for ^3 {
    my $pick = @a.pick;
    ok @a.first(/^$pick$/), "$_. .pick'ed exists in orignal list";
}

# for ^3 {
#     my @picks = @a.pick(2);
#     is @pick.elems, 2, '.pick(2) returns two elements';
#     ok @picks[0] ne @picks[1], ‘.pick(2) doesn't duplicate’;
# }
