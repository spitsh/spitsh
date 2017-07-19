use Test; plan 8;

class Foo {
    constant $:value = "foo";

    static method value~ { $:value }
}

is $Foo:value, "foo", '$Foo:value';

is Foo.value, "foo", 'Foo.value';

is eval(value => 'bar'){ print $Foo:value }.${sh}, 'bar', '$Foo:value (value => "bar")';
is eval(value => 'bar'){ print "$Foo:value" }.${sh}, 'bar', '$Foo:value (value => "bar")';
is eval(value => 'bar'){ ${ printf '%s' $Foo:value } }.${sh}, 'bar', '$Foo:value (value => "bar")';
is eval(value => 'bar'){ print Foo.value }.${sh}, 'bar', 'Foo.value (value => "bar")';

is eval('Foo:value' => 'baz'){ print $Foo:value }.${sh}, 'baz',
  '$Foo:value (Foo:value)';


is eval('Foo:value' => 'baz'){ print $:<Foo:value> }.${sh}, 'baz',
  '$:<Foo:value> (Foo:value => baz)';
