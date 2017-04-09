use Test;
use Spit::Compile;

plan 1;

nok compile(name => 'ternary in conditional', Q{
         (${true} ?? ${true} !! ${true}) && say "win"
        }).contains('test'), ‘ternary used in a conditional doesn't need test’;
