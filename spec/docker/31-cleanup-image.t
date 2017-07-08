use Test;

plan 2;

my $img1 = Docker.create('alpine').commit.cleanup;
my $img2 = Docker.create('alpine').commit.cleanup;

ok $img1 && $img2, ‘.create'd images exist’;

FILE-CLEAN nok $img1 && $img2, 'removed by END';
