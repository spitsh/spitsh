use Test;
plan 3;

constant $foo = on {
    Debian { 'debian' }
    RHEL   { 'redhat'  }
};

my $rhel = eval(os => RHEL){ say $foo };
ok $rhel.contains('redhat'),'constant = on {...} (RHEL)';
nok $rhel.contains('debian'),"doesn't contain debian";
my $deb = eval(os => Ubuntu){ say $foo };
ok $deb.contains('debian'), 'constant = on {...} (Ubuntu)';
