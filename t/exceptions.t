use Spit::Compile;
use Test;
use Spit::Exceptions;
plan 7;

my $name = 'syntax-tests';
throws-like { compile( '"', :$name) },
            SX::Expected,'stray "',
            message => q|Expected closing '"'.|;

throws-like { compile( '"foo', :$name ) },
            SX::Expected, 'unfinished "',
            message => q|Expected closing '"'.|;

throws-like { compile('foo',:$name) },
            SX::Undeclared,'undeclared sub',
            message => q|Sub 'foo' hasn't been declared.|;

throws-like { compile('foo "bar"',:$name) },
            SX::Undeclared,'undeclared sub with arg',
            message => q|Sub 'foo' hasn't been declared.|;

throws-like { compile('foo()',:$name) },
            SX::Undeclared,'undeclared sub()',
            message => q|Sub 'foo' hasn't been declared.|;

# throws-like { compile('Foo',:$name) },
#             SX::Undeclared,'undeclared class',
#             message => "name 'Foo' hasn't been declared.";

throws-like { compile('say $*foo',:$name) },
            SX::Undeclared,'undeclared option',
            message => "Option 'foo' hasn't been declared.";

throws-like { compile('my $*foo; say $*foo', :$name) },
            SX::RequiredOption,"required option not set",
            message => "Option foo used but no value provided for it and it doesn't have default.";
