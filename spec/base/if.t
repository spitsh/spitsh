use Test;
plan 46;

if True {
   pass "basic if works";
}

unless False {
    pass "basic unless works";
}

if False {
    flunk 'if false else true';
} else {
    pass 'if false else true'
}

if False {
    flunk 'if false else true else';
} elsif True {
    pass  'if false else true else';
} else {
    flunk 'if false else true else';
}

# Empty if just to test that it doesn't result in syntax errors
if False {

} elsif False {

} else {

}

if True {
    if True {
        pass 'nested not-returning if true';
    }
}

# now do most of the same tests runtime variables
my $true = True;
my $false = False;

if $true {
    pass "basic if works";
}

if $false {
    flunk 'if false else true';
} else {
    pass 'if false else true'
}

if $false {
    flunk 'if false else true else';
} elsif $true {
    pass  'if false else true else';
} else {
    flunk 'if false else true else';
}

if $false {

} elsif $false {

} else {

}

if $true {
    if $true {
        pass 'nested not-returning if true';
    }
}

if $true or $false {
    pass "true junction as if cond";
}

if $true and $false {
    flunk "false junciton as if cond";
} else {
    pass "false junciton as if cond";
}

{
    my $a = 5;
    my $b = 7;

    if $b > $a {
        pass "numeric comparison as if cond"
    }
}

{
    my $str = "";
    if $str {
        flunk qq{\$str="$_"} ~ '; if $str {...}';
    } else {
        pass qq{\$str="$_"} ~ '; if $str {...}';
    }

    $str = "foo";

    if $str {
        pass qq{\$str="$_"} ~ '; if $str {...}';
    } else {
        flunk qq{\$str="$_"} ~ '; if $str {...}';
    }
}

{
    class Bar {
        method ?Bool { $self eq 'bar' }
    }
    class Foo {
        method ?Bool { $self.is-foo }
        method ?is-foo { $self eq 'foo' || $self eq 'fooish' }
        method to-bar( -->Bar ){ $self ~ 'derp' }
    }

    if Foo<bar> {
        flunk "Object boolification (false)";
    } else {
        pass "Object boolification (false)";
    }

    unless Foo<bar> {
        pass "Object boolification (false - unless)";
    } else {
        flunk "Object boolification (false - unless)";
    }

    if Foo<foo> {
        pass "Object boolification (true)";
    } else {
        flunk "Object boolification (true)"
    }

    if Foo<foo> {
        is $_, 'foo',"subject variable is set";
    }

    unless Foo<bar> {
        is $_, 'bar',"subject variable is set (unless)";
    }

    if Foo<foo>.is-foo {
        is $_,'foo','explicit method call as condition sets $_';
    }

    if Foo<foo> {
        if Foo<fooish> {
            is $_,'fooish','subject variable nested if';
        }
        is $_,'foo','subject variable is lexical';
    }

    if Foo<foo>.to-bar {
        is $_ ,'bar',"subject variable is set after method call";
    }

    if Foo<foo> {
        if $true {
            is $_,'foo',q<nested if without subject doesn't clobber>;
        }
    }


    if Foo<foo> -> $var {
        is $var,'foo','-> $var';
        is $var.WHAT,'Foo','-> $var default type in if'
    } else {
        flunk '-> $var';
    }

    if Foo<bar> -> $var {
        flunk '-> $var in else';
    } else {
        is $var,"bar",'-> $var in else';
        is $var.WHAT,'Foo','-> $var default type in else'
    }

    if Foo<foo> -> Bar $var {
        is $var,'foo','-> Bar $var';
        is $var.WHAT,'Bar','-> Bar $var type';
    }

    if Foo<bar> {

    } elsif Foo<baz>  {

    } else {
        is $_,"baz",'-> $var in else with elsif';
    }
}

{
    pass 'statement mod (true)' if $true;
    my $canary = True;
    $canary = False if $false;
    ok $canary,'statement mod (false)';

    $canary = False unless $false;
    nok $canary,'statement mod unless';

    is $_,"true",'$_ is set in statement mod' if Cmd<true>;
    is .WHAT,'Cmd','$_ type is right in statement mod' if Cmd<true>;

    is ${printf "%s-%s" ("one" if $true) ("two" if $false) ("three" if $true) },
       "one-three", '${printf (X if true)} flattens out in cmd';

    is ${printf "%s-%s-%s" ("one" if $true) $("two" if $false) ("three" if $true) },
       "one--three", '$(X if false) itemizes';

    is ${printf "%s-%s" ("one" if True) ("two" if False) ("three" if True) },
       "one-three", '${printf (X if true)} flattens out in cmd (compile time)';

    is ${printf "%s-%s-%s" ("one" if True) $("two" if False) ("three" if True) },
       "one--three", '$(X if false) itemizes (compile time)';
}

{
   my Bool $a = (
     if $true {
        $true;
     }
   );

   ok $a,"if on RHS (Bool)";

   $a = (
       if $false {
           $true;
       }
   );
   nok $a,"if on RHS (Bool - False)"
}

{
    my $str = (
        if $true {
            "foo";
        }
    );

    is $str, "foo","if on RHS (Str)";

    $str = (
        if $true {
            say "ignore this";
            "foo";
        }
    );
    is $str,"foo","say() doesn't corrupt return value";
}

{
    is (if $true { "foo" } else { "bar" }).
        ${cat}, 'foo', 'piping result of if';
}

{
    my @cmd = 'awk','/lose/{ print "lose"; exit 1; } { print "win" }';

    my $res;

    if ($res ~= "winner".${@cmd}; $?) {
        is $res, "win", '$? command (true)';
    } else {
        flunk '$? command (false)';
    }

    if ($res ~= "loser".${@cmd}; $?) {
        flunk '$? command (false)'
    } else {
        is $res,"winlose", '$? command (true)';
    }
}
