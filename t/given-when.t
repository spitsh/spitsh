use Spit::Compile;
use Test;
use Spit::Exceptions;

plan 1;

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
