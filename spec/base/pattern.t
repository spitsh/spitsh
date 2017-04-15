use Test;

plan 1;

sub ~pattern(Pattern $pattern) { $pattern };

is pattern(/foo/), '*foo*', 'Pattern in signature';
