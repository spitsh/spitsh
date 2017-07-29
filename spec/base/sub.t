use Test; plan 36;

#XXX: This file is in the process of being split up and moved to spec/sub/

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
    sub foo($a,){
        is $a, 'foo','trailing , in parameter list';
    }
    foo('foo');
}



{
    sub echo($a)~ { $a }
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
    sub foo-bar($a) {
        is $a,"foo5","kebab-case sub works";
    }
    foo-bar "foo5";
}


{
    sub get-five ( )-->Int{ 5 }
    is get-five() + get-five(), 10,"subs that return ints work";
}


{
    sub plus-five(Int $i )-->Int {$i + 5}
    is plus-five(2),7,"Int typed param works";
    is plus-five(2,),7, "trailnig , in arg list";
}

{
    sub per-os()~ on {
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
    sub check-re-enter+ is return-by-var {
        my $foo = ++$canary;
        $:NULL.write($foo);
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
    sub list-param(Int @a )-->List[Int] {
        $_ + 2 for @a;
    }

    is list-param(<1 2 3 4>), <3 4 5 6>, 'Int @a as a param';
}


{
    sub cmd-sub~ ${ printf 'foo' };

    is cmd-sub(), 'foo', 'sub ${..} syntax';

    is eval{ cmd-sub }.${sh}, '', "sub returning Str in Any ctx should be silent";
}


{
    sub simple-slurpy(*@a)@ {
        "zero", @a;
    }
    is simple-slurpy(), "zero", '(*@a) with 0 args';
    is simple-slurpy("one"), <zero one>, '(*@a) with 1 arg';
    is simple-slurpy("one", "two", "three"), <zero one two three>,
       '(*@a) three args';
    is simple-slurpy("one", <two three>), <zero one two three>,
       '<...> flattens out into slurpy';
}

{
    sub less-simple-slurpy($a, $b, *@a)@ {
        "\$a=$a", "\$b=$b","\@a=@a"
    }

    is less-simple-slurpy("one", "two", "three"), <$a=one $b=two @a=three>,
      '($a, $b, *@a) with three args';

    is less-simple-slurpy("one", "two", "three", "four"), <$a=one $b=two @a=three four>,
      '($a, $b, *@a) with four args';
}

{
    sub for-slurpy($c, *@a)@ {
        .uc for @a;
    }

    is for-slurpy("one", <two three four>), <TWO THREE FOUR>,
      'iterate over slurpy parameter';
}

{
    sub typed-slurpy(File *@a) { ${ printf @a >X } }
    typed-slurpy("one", "two", "three");
    pass 'typed slurpy call in Any context';
}

{
    sub primitive-typed-slurpy(Int *@a)+ { +@a }
    is primitive-typed-slurpy(1,2,<3 4 5>,6), 6,
      'primitive typed slurpy with list in arguments';
}
