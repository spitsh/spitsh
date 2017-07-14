use Test;

constant $:spit = 'spit';

is ${ $:spit eval "say 'hello world'" | sh }, 'hello world', 'hello world';
