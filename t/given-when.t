use Spit::Compile;
use Test;
use Spit::Exceptions;

plan 3;

ok compile(
    q{
        my $foo = "foo";
        given $foo {
            when /fo$/ { say "yo" }
            when /^oo/ { say "yo" }
            default    { say "yo" }
        }
    },
    name => 'given-when-test',
).contains("esac"),'given "foo" .. when /../ ends up us a switch statement';

ok compile(
    q{
        my $c = "foo";
        given $c {
            when /fooo/ { say "yo" }
            when /f.*/ { say "yo" }
        }
    },
    name => 'no-double-stars',
) ~~ all(*.contains('esac'), !*.contains('**')),
    ‘regex ending in .* doens't duplicate ** when it becomes a case’;


ok compile(name => "check prompt", 'prompt("foo")').contains('esac'),
    ‘prompt's switch gets cased’;
