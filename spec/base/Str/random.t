use Test;

plan 1;

ok Str.random(7).matches(/^[a-zA-Z0-9]{7}$/),
  '.random(7) returns 7 random alphanumeric characters';
