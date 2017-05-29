use Test;

plan 27;

{
    class Foo {
        static method doit~ { "foo" }
    }

    class Bar {
        static method doit~ { "bar" }
    }

    is Foo.doit,"foo","basic static method call";
    is Bar.doit(),"bar","basic static method call again";
    is Bar
       .doit(),"bar", 'method call with \n before the dot';
    is Bar.
       doit(),"bar", 'method call with \n after teh dot';
}


{
    class Parent {
        static method dont-override~ { ":D"}
        static method override~      { "parent" }
        static method return-self^   { "parent" }
    }

    class Child is Parent {
        static method override~ { "child" }
        static method child-only~ { "child-only" }
    }

    is Child.dont-override,':D','child inherited from parent';
    is Child.override,"child",'child overridden parent';
    is Child.child-only,"child-only",'child-only method works';
    is Parent.override,"parent","overridden method in parent still works";
    is Parent.return-self.WHAT, 'Parent', '* return on parent returns Parent';
    is Child.return-self.WHAT, 'Child', '* return Child returns Child';
}


{
    class Foo { }
    is Foo<bar>,'bar','Foo<bar>';
    is Foo('bar'),'bar','Foo{ }';
    is Foo( 'bar' ),'bar','Foo{ "bar" }';
    ok Foo<bar>.chars == 3,'classes inherit from Str';
}

{
    class Foo {
        method second($a)~ { $self ~ $a ~ "baz"}
        method first($a)~  { $self.second($a) }
        method return-self^ { $self.uc }
    }

    is Foo<foo>.first("bar"),"foobarbaz","methods can call other methods";
    is (Foo<foo>.first: "bar"), "foobarbaz", '.method: syntax';
    is Foo<foo>.return-self.WHAT, 'Foo', '* return on instance';

    given Foo<foo> {
        is .first("bar"), "foobarbaz", 'topic method-call($a)';
        is (.first: "bar"), "foobarbaz", 'topic method-call: $a';
    }
}

{
    class Foo {
        static method cmd~ ${ printf 'foo' }
    }

    is Foo.cmd, 'foo', 'method ${...} syntax';
}

{
    class Parent {}

    class Child is Parent {}

    augment Parent {
        static method return-self^ { "augment return-self"}
    }

    is Parent.return-self, 'augment return-self', 'call method added by augment';
    is Child.return-self, 'augment return-self', 'call method added by augment on child';
}

{
    class HasSlurpy {
        method slurpy(*@a)@ {
            "\$self=$self", "\@a=@a";
        }

        method slurpy2($a, *@a)@ {
            "\$self=$self", "\$a=$a", "\@a=@a";
        }
    }

    is HasSlurpy<one>.slurpy("two", "three"), <$self=one @a=two three>,
      'non-static method (*@a) 2 args';

    is HasSlurpy<one>.slurpy2("two", "three"), <$self=one $a=two @a=three>,
      'non-static method ($a, *@a) 2 args';
}

{
    class Piping-Methods {

        method one~ is no-inline{
            $self.${cat}
        }
        method two~ is no-inline {
            $self.one;
        }

    }

    is Piping-Methods("foo\n").two.bytes, 4, ‘piping methods shouldn't lose newline’;
}

{
    class Coercion-Priority is Any {
        method File { "file" }
        method Str  { "str"  }
    }

    is Coercion-Priority<foo>, "str", '.Str in Str context';
    is File(Coercion-Priority<foo>), "file", '.File in File context';
}
