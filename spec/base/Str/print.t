use Test;

plan 6;

is eval{ ${ printf 'foo' }.say }.${sh}.bytes, 4,
  '.say adds a trailing newline';
is eval{ ${ printf 'foo\n' }.say }.${sh}.bytes, 4,
  ‘.say doesn't add a duplicate newline’;

is eval{ ${ printf 'foo'  }.note }.${sh !>~ >X}.bytes, 4,
  '.note adds a trailing newline';
is eval{ ${ printf 'foo\n' }.note }.${sh !>~ >X}.bytes, 4,
  ‘.note doesn't add a duplicate newline’;


is eval{ ${ printf 'foo' }.print }.${sh}.bytes, 3,
  ‘.print doesn't add a trailing newline 1’;
is eval{ ${ printf 'foo\n' }.print }.${sh}.bytes, 4,
  ‘.print doesn't add a trailing newline 2’;
