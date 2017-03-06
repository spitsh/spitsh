use Spit::Compile;
use Test;
plan 2;
my $name = 'sanity-tests';
nok compile(q|say "hello world"|,:$name).contains('e()'),"e() isn't included for no reason";

is compile(
    q{  foo("wee");
        sub ~foo($a) { $a ~ "bar" ~ "makeitlongenoughsonoinline" };
    },:$name).match(/'foo()'/,:g).elems,1,'only one definition of post-declared sub';
