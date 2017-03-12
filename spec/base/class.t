use Test;

plan 10;

{
    class Foo {
        static method ~doit { "foo" }
    }

    class Bar {
        static method ~doit { "bar" }
    }

    is Foo.doit,"foo","basic static method call";
    is Bar.doit,"bar","basic static method call again";
}

{
    class Parent {
        static method ~dont-override { ":D"}
        static method ~override      { "parent" }
    }

    class Child is Parent {
        static method ~override { "child" }
        static method ~child-only { "child-only" }
    }

    is Child.dont-override,':D','child inherited from parent';
    is Child.override,"child",'child overridden parent';
    is Child.child-only,"child-only",'child-only method works';
    is Parent.override,"parent","overridden method in parent still works";
}


{
    class Foo { }
    is Foo<bar>,'bar','Foo<bar>';
    is Foo{'bar'},'bar','Foo{ }';
    ok Foo<bar>.chars == 3,'classes inherit from Str';
}

{
    class Foo {
        method ~second($a) { $self ~ $a ~ "baz"}
        method ~first($a)  { $self.second($a) }
    }

    is Foo<foo>.first("bar"),"foobarbaz","methods can call other methods";

}
