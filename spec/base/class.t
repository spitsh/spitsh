use Test;

plan 10;

{
    class Foo {
        method ~doit { "foo" }
    }

    class Bar {
        method ~doit { "bar" }
    }

    is Foo.doit,"foo","basic method call works";
    is Bar.doit,"bar","basic method call works again";
}

{
    class Parent {
        method ~dont-override { ":D"}
        method ~override      { "parent" }
    }

    class Child is Parent {
        method ~override { "child" }
        method ~child-only { "child-only" }
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
        method ~second($a) { self ~ $a ~ "baz"}
        method ~first($a)  { self.second($a) }
    }

    is Foo<foo>.first("bar"),"foobarbaz","methods can call other methods";

}
