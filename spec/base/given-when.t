use Test;

plan 20;

{
    my $a = "foo";
    given $a {
        when 'bar' { flunk 'basic str' }
        when 'fo' { flunk 'basic str' }
        when 'fo*' { flunk 'basic str' }
        when 'foo' { pass  'basic str' }
    }
}

{
    my $x = 3;
    given $x {
        when $_ < 3 { flunk "numeric cmp given" }
        when $_ == 3 { pass "numeric cmp given"  }
        default { flunk 'numeric cmp given' }
    }
}

{
    my $y = 3;
    when $y > 3  { flunk 'when without $_' }
    when $y < 3  { flunk 'when without $_' }
    when $y == 3 { pass  'when without $_' }
}

{
    my $b = "NOPE";
    given $b {
        when 'foo' { }
        when 'bar' { }
        default { is $_, "NOPE",'default with string comparison (var)' }
    }

    # Here to check that even though this does nothing it works
    given $b {
        when $_ gt "The best" { "foo" }
        when $_ gt "Anyone"   { "bar" }
        default { "default" }
    }
}

{
    given "NOPE" {
        when 'foo' { }
        when 'bar' { }
        default { is $_,"NOPE",'default with string comparison'}
    }
}

{
    my $x = given "foo" {
        when "bar" { "lose"}
        when "foo" { "win" }
    };
    is $x, "win", "= assignment to given";
}

{
    my $c = "foo";

    given $c {
        when /food/ { flunk 'basic regex' }
        when /fo/   { pass 'basic regex'  }
    }

    given $c {
        when /fooo/ { flunk 'quantifier regex' }
        when /f.*/ { pass 'quantifier regex' }
    }

    given $c {
        when /bar|baz/ { flunk 'alternation regex' }
        when /fee|foo/ { pass 'alternation regex'  }
    }
    given $c {
        when /fo$/ { flunk 'anchor regex' }
        when /^foo$/ { pass 'anchor regex' }
    }
    given $c {
        when /^oo$|^fo$/ { flunk 'alternation and anchor' }
        when /^foo$|^bar$/ { pass 'alternation and anchor' }
    }

    given $c {
        when /[asd]oo/  { flunk 'character class' }
        when /[asdf]oo/ { pass 'character class' }
    }

    given $c {
        when /[^asdf]oo/ { flunk 'negated character class' }
        when /[^asd]oo/  { pass  'negated character class' }
    }

    given $c {
        when /fo$/ { flunk 'caseable regex with default' }
        when /^oo/ { flunk 'caseable regex with default' }
        default    { pass 'caseable regex with default'  }
    }

    given $c {
        when /fo\so/ { flunk 'non-caseable regex' }
        when /fo(p|o)/ { pass 'non-caseable regex' }
    }
}

{
    my $d = '[foo]';
    given $d {
        when /^[foo]oo/    { flunk 'character class with []]' }
        when /[[z]foo[]z]/ { pass  'character class with []]' }
        default            { flunk 'character class with []]' }
    }

    given $d {
        when /^[foo]oo/   { flunk 'pass escaped \\[' }
        when /\[foo\]/    { pass 'pass escaped \\['  }
        default           { flunk 'character class with []]' }
    }
}

{
    given ${echo "foo"} {
        when /food/ { flunk 'cmd as given arg' }
        when /fo/   { pass 'cmd as given arg'  }
    }
}

{
    my $canary;
    sub ?bewl($foo) {
        given $foo {
            when /food/   { $canary = True;  True }
            when /fo/     { $canary = True;  True }
            when /foo/    { $canary = True;  True }
        }
    }

    if bewl("foo") {
        pass 'caseable as a Bool return value';
    } else {
        flunk 'caseable as a Bool return value';
    }
    ok $canary, ‘doesn't get run in a subshell’;
}
