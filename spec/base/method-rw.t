use Test;
plan 3;
class Foo {
    method concat-with($a) is rw { $self ~ $a }
    method static-concat($a) is rw { 'bar' ~ $a };
}

my Foo $a = "foo";
$a.concat-with('bar');
$a.concat-with('baz');
is $a,"foobarbaz",'self-mutating call works';
is Foo<foo>.concat-with("bar"),'foobar',"self-mutating call just returns the result if the invocant is immutable";
$a.static-concat("baz");
is $a,"barbaz","is rw works with static methods";
