use Spit::Compile;
use Test;
use Spit::Exceptions;
use Terminal::ANSIColor;
plan 10;

my $name = 'syntax-tests';
throws-like { compile( '"', :$name) },
            SX::Unbalanced,'stray "',
            message => q|Couldn't find closing ‘"’ to finish double-quoted string|;

throws-like { compile( '"foo', :$name ) },
            SX::Unbalanced, 'unfinished "',
            message => q<Couldn't find closing ‘"’ to finish double-quoted string>;

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

# throws-like { compile('my $*foo; say $*foo', :$name) },
#             SX::RequiredOption,"required option not set",
#             message => "Option foo used but no value provided for it and it doesn't have default.";

throws-like { compile('sub foo($a,$b) { }; foo("bar")',:$name)},
              SX::BadCall,"too few arguments",
              gist => *.&colorstrip.contains('sub foo($a,$b) { }; foo("bar", $b↩)');

throws-like { compile('sub foo($a,$b) { }; foo("foo","bar","baz")',:$name) },
              SX::BadCall,"too many arguments",
              gist => *.&colorstrip.contains('sub foo($a,$b) { }; foo("foo","bar","baz")');

throws-like { compile('my $a = "foo"; $a .= "foo".${cat}',:$name) },
              SX::Invalid, '.= to a command that already has input';

throws-like {
    compile name => 'parameterized class bad call',
    q:to/END/;
    class Foo[Type] {
        static method echo(Type $a --> Type) { $a }
    }
    Foo[Int].echo("blah");
    END
}, SX::TypeCheck,"wrong type of argument to parameterized class method";
