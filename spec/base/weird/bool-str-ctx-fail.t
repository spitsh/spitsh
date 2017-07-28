use Test; plan 1;

is eval(){ say Cmd<printf>.exists }.${sh}, 1,
  ‘weird true Bool in Str context not being 1’;
