use Test;

plan 4;

my @a = <one two three>;

for ^3 {
    my $pick = @a.pick;
    ok @a.first(/^$pick$/), "$_. .pick'ed exists in orignal list";
}

for ^10 {
    my @picks = @a.pick(2);
    when 0 {
        is @picks.elems, 2, '.pick(2) returns two elements';
    }
    flunk ‘.pick(2) doesn't duplicate’ if @picks[0] eq @picks[1];
}
