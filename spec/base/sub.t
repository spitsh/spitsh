use Test;

plan 32;

{
    sub foo() {
        pass "sub with no args works";
    }
    foo();
    foo;
    foo   ;
}

{
    sub foo($a) {
        is $a,"foo",'$a has correct value';
    }
    foo("foo");
}

{
    sub ~echo($a) { $a }
    my @a = <one two three>;
    is echo(<one two three>), @a, "<one two three> is a single arg";
    is echo(@a), @a, '@a is a single arg';
    is echo(("one", "two","three")), @a, '(one two three) is a single arg';
}

{
    sub foo($a,$b) {
        is $a,"foo1",'$a has correct value';
        is $b,"bar1",'$b has correct value';
    }
    foo("foo1","bar1");
}

{
    sub foo($a,$b,$c) {
        is $a,"foo2",'$a has correct value';
        is $b,"bar2",'$b has correct value';
        is $c,"baz",'$c has correct value';
    }

    foo("foo2","bar2","baz");
}

{
    my $syntax;
    sub foo(:$a,:$b) {
        is $a,"foo3","named $a has correct value ($syntax)";
        is $b,"bar3","named $b has correct value ($syntax)";
    }

    $syntax = ':<..>';
    foo(:a<foo3>,:b("bar3"));
    $syntax = '=>';
    foo(a => "foo3",b => "bar3");
    $syntax = '=> A ~ B';
    my $foo = "foo";
    my $bar = "bar";
    foo(a => $foo ~ 3,b => $bar ~ 3 );

}

{
    sub foo(:$a,:$b,$c) {
        is $a,"foo4","named $a with pos";
        is $b,"bar4","named $b with pos";
        is $c,"baz1","pos $c with named works";
    }

    foo :a<foo4>,"baz1",:b<bar4>;
}

{
    sub foo-bar($a) {
        is $a,"foo5","kebab-case sub works";
    }
    foo-bar "foo5";
}


{
    sub get-five ( --> Int ){ 5 }
    is get-five() + get-five(), 10,"subs that return ints work";
}


{
    sub plus-five(Int $i --> Int) {$i + 5}
    is plus-five(2),7,"Int typed param works";
}

{
    sub ~per-os() on {
        RHEL { 'redhat' }
        Debian { 'debian' }
    }

    my $rhel = eval(os => RHEL){ say per-os() };
    my $deb  = eval(os => Debian){ say per-os() };
    my $cent = eval(os => CentOS){ say per-os() };

    ok $rhel.contains('redhat'),'os switch in sub def on redhat contains redhat';
    nok $rhel.contains('debian'),'os switch in sub def on redhat not contains debian';
    ok $deb.contains('debian'),'os switch in sub def on debian contains debian';
    nok $deb.contains('redhat'),'os switch in sub def on debian not contains redhat';
    ok $cent.contains('redhat'),"centos gets redhat's";
}

{
    my $canary = 0;
    sub +check-re-enter is return-by-var {
        my $foo = ++$canary;
        $*NULL.write($foo);
        $foo;
    }

    my $a = check-re-enter();
    my $b = check-re-enter();
    nok $a == $b,'my $foo = ... as arg works more than once';
}

{
    sub dolla($_) {
        when 'foo' { pass  '$_ as parameter' }
        default    { flunk '$_ as parameter' }
    }

    dolla("foo");
}

{
    sub list-param(Int @a --> List[Int]) {
        $_ + 2 for @a;
    }

    is list-param(<1 2 3 4>), <3 4 5 6>, 'Int @a as a param';
}
