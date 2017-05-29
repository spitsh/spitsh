use Spit::Compile;
use Test;
plan 5;
my $name = 'sanity-tests';
nok compile(q|say "hello world"|,:$name).contains('e()'),"e() isn't included for no reason";

is compile(
    q{  foo("wee");
        sub foo($a)~ { $a ~ "bar" ~ "makeitlongenoughsonoinline" };
    },:$name).match(/'foo()'/,:g).elems,1,'only one definition of post-declared sub';

is compile(
    :$name,
    q{ <one two three>; for <four five six> {  } }
).match(/'IFS'/,:g).elems,1, 'only one declaration of IFS';

is compile(
    name => "no double curl",
    Q{ say $*curl }
).match(/'curl='/,:g).elems,1,'only one declaration of curl';

nok compile(
    name => 'no double newline',
    'say $*NULL; die "herp"'
).contains("\n\n"), ‘depending on $*NULL twice doesn't create a gap’;
