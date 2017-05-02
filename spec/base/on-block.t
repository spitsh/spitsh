use Test;
plan 4;

{
    constant $foo = on {
        Debian { 'debian' }
        RHEL   { 'redhat'  }
    };

    my $rhel = eval(os => RHEL){ say $foo };
    ok $rhel.contains('redhat'),'constant = on {...} (RHEL)';
    nok $rhel.contains('debian'),"doesn't contain debian";
    my $deb = eval(os => Ubuntu){ say $foo };
    ok $deb.contains('debian'), 'constant = on {...} (Ubuntu)';
}
{
    constant $bar = on {
        Debian ${ printf 'debian' }
        RHEL   ${ printf 'redhat' }
    }

    is eval(os => RHEL){ print $bar }.${sh}, 'redhat', 'on { OS ${...} } syntax';
}
