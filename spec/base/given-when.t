use Test;

plan 12;
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
        when /^oo$|^fo$/ { flunk 'alternationa and anchor' }
        when /^foo$|^bar$/ { pass 'alternationa and anchor' }
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
    given ${echo "foo"} {
        when /food/ { flunk 'cmd as given arg' }
        when /fo/   { pass 'cmd as given arg'  }
    }
}
