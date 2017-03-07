use Spit::Compile;
use Test;
use Spit::Exceptions;
use Terminal::ANSIColor;
plan 9;

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

throws-like { compile('sub foo($a,$b) { }; foo("bar")',:$name)},
              SX::BadCall,"too few arguments",
              gist => *.&colorstrip.contains('sub foo($a,$b) { }; foo("bar"⏏)');

throws-like { compile('sub foo($a,$b) { }; foo("foo","bar","baz")',:$name) },
              SX::BadCall,"too many arguments",
              gist => *.&colorstrip.contains('sub foo($a,$b) { }; foo("foo","bar",⏏"baz")');
