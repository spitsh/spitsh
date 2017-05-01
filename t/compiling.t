use Test;
use Spit::Compile;

plan 2;

nok compile(name => 'ternary in conditional', Q{
         (${true} ?? ${true} !! ${true}) && say "win"
        }).contains('test'), ‘ternary used in a conditional doesn't need test’;

nok compile(name => 'no list echoing into grep', Q{
    my $t = /t/;
    say <one two three>.grep(/$t/);
}).contains('e(){'), ‘list into grep doesn't echo’;
