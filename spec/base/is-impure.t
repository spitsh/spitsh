use Test;
plan 3;



{
    my $canary = False;
    sub ~foo() is return-by-var {
        $canary = True;
        "bar";
    }

    my $res = foo();

    is $res,"bar",'return value from return-by-var';
    ok $canary,   'variable side effects kept';
}

{
    my $canary = False;
    class Foo {
        method ?faa() is impure {
            $canary = True;
            $self.${tr o a | grep faa}
        }
    }

    if Foo<foo>.faa {
        ok $canary, 'impure call as cond has side effects';
    } else {
        flunk 'impure call as cond has side effects';
    }
}
