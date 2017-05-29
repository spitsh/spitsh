use Test;

plan 11;

{
    sub foo($a = "foo")~ { $a }
    is foo(), "foo", '1 pos basic: default gets set';
    is foo("bar"), "bar", ‘1 pos basic: doesn't get set if arg is passed’;
}

{
    sub foo($a = "foo")~ {
        my $transform = $a.uc;
        "{$transform}D";
    }
    is foo(), "FOOD", '1 pos transformed: default gets set';
    is foo(), "FOOD", ‘1 pos transformed: doesn't get set if arg is passed’;
}

{
    sub bar(:$a = "bar")~ { $a }
    is bar(), "bar", '1 named basic: default gets set';
    is bar(a => "foo"), "foo", ‘1 named basic: doesn't get set if arg is passed’;
}

{
    sub baz($a, $b = "foo")~{ "$a $b".uc }
    is baz("foo"), "FOO FOO", '2 pos transformed: default gets set';
    is baz("foo", "bar"), "FOO BAR",
      ‘2 pos transformed: doesn't get set if arg is passed’;

    sub call-default($a = baz("win"), :$b = $*os.name )~ { "{$a.lc} $b" }

    is call-default(), "win foo {$*os.name}", '1 pos 1 named: default are calls';
}

{
    sub typed-with-default(Int $a = 1)+{ $a * $a * $a }

    is typed-with-default(), 1, '1 typed pos: default gets set';
    is typed-with-default(5), 125, ‘1 typed pos: doesn't get set if arg is passed’;
}
