use Test;

plan 5;

is q{
    one
    two
    three
}, "one\ntwo\nthree\n", 'q»{\n...}';

is q{one
     two
     three}, <one two three>, 'q»{...}';

is q⟪{
         say "hello world"
    }⟫,
'{
    say "hello world"
}', 'q⟪{\n...}⟫}';


my @a = <one two three>;
my $quote =
qq(foo

   { ($_ for @a).join(',') }

   bar);

is $quote,
'foo

one,two,three

bar', ‘block doesn't eat whitespace’;

#-------

my $foo = True;
my $bar = True;

my $quote2 =

qq(
    {  $bar && 'bar' }

      ---
    { 'foo' if $foo }
);

is $quote2,
'bar

  ---
foo
', 'two quoted blocks';
