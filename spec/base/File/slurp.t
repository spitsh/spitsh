use Test; plan 3;

{
    given File.tmp {
        .write(<foo bar baz>);
        is .slurp[1],'bar','.slurp[1]';
    }
}

{

    nok quietly { eval{
        given File.tmp {
            .remove;
            my $txt = .slurp;
            ${true};
        }
    }.${sh !>X}}, 'slurp on non-existant file dies'
}

{
    ok eval{
        given File.tmp {
            .remove;
            my $txt = .try-slurp;
            ${true};
        }
    }.${sh}, ‘try-slurp on non-existant file doesn't die’;
}
