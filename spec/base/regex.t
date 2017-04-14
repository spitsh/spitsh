use Test;

plan 37;

ok "foo" ~~ /oo$/,'basic re match (true)';
nok "foo" ~~ /ar$/,'basic re match (false)';

{
    my $_ = "foo";

    if /^fo/ {
        pass "literal regex in Bool ctx (true)";
        is $_,"foo","literal regex in Bool ctx preserves subject";
    } else {
        flunk "literal regex in bool context (true)";
    }

    if /bar/ {
        flunk "literal regex in Bool ctx (false)";
    } else {
        pass "literal regex in Bool ctx (false)";
    }
}

{
    my $url = "https://irclog.perlgeek.de/perl6/2017-03-30";
    if $url.match(/.+:/) {
        is @/.elems,1, "successful match without capture group has one element";
        is @/[0], "https:", 'it is the entirity of the matched text';
    }

    if $url.match(/^(.+):\/\/([^/]+)\/?(.*)$/) {
        is @/.elems, 4, '3 capture groups means 4 elems';
        is @/[0],$url,'0th element is the entire match';
        is @/[1],'https','1st element is the scheme';
        is @/[2],'irclog.perlgeek.de','2nd element is the host';
        is @/[3], 'perl6/2017-03-30', '3rd element is the path';

        if @/[2].matches(/^irclog\.perlgeek\.de/) {
            nok @/[3].matches(/^perl5/),'.matches basic match';
            ok  @/[3].matches(/^perl6/),‘matches doesn't clobber @/’;
        }
    }

    if $url.match(rx‘^(.+)://([^/]+)/?(.*)$’) {
        is @/.elems, 4, '3 capture groups means 4 elems (rx)';
        is @/[2], 'irclog.perlgeek.de', '0th element is the entire match (rx)';
    }

    if $url.match(/^ftp/) {
        flunk 'fail to match returns false';
    } else {
        nok @/, 'fail to match resets @/';
        pass 'fail to match returns true';
    }
}

{
    nok 'dude' ~~ /^\d/, ‘\d doesn't match a literal 'd'’;
    ok 'dude'  ~~ /\D/,  ‘\D does match a literal 'd'’;
    ok '123'   ~~ /^\d/, '\d does match a number';
    nok '123'  ~~ /^\D/, ‘\D doesn't match a number’;
}

{
    my $sentence = 'The quick brown fox jumped over the lazy dog.';
    if $sentence ~~ /^\w+(\s+\w+)+\.$/ {
        is @/[0], $sentence, 'The whole sentence was put in @/';
        is @/[1], ' dog',    'The capture group holds the last capture';
    }
    nok $sentence ~~ /^\W+(\s+\w+)+\.$/, ‘\W doesn't match what \w did’;
    nok $sentence ~~ /^\W+(\S+\w+)+\.$/, ‘\S doesn't match what \s did’;
}

{
    nok '[fo]' ~~ rx[^[fo]$],  ‘using rx[] doesn't mean they match literally’;
    ok  'fo'   ~~ rx[^[of]+$], 'rx[] preserves [] metachar';
}

{
    ok  'zzz' ~~ /^z{3}$/, ‘{n} the right amount’;
    nok 'zzz' ~~ /^z{2}$/, ‘{n} one less than the right amount’;
    nok 'zzz' ~~ /^z{4}$/, ‘{n} one more than the right amount’;

    ok  'zzzz'    ~~ /^z{2,4}$/, '{n,m} with m repeat';
    ok  'zz'      ~~ /^z{2,4}$/, '{n,m} with n repeat';
    nok 'z'       ~~ /^z{2,4}$/, '{n,m} with n - 1 repeat';
    nok 'zzzzz'   ~~ /^z{2,4}$/, '{n,m} with n + 1 repeat';
}

{
    my $interpolate = /\([Oo^*][_.-][Oo^*]\)/;
    ok '<(o_O)><(^_^)><(*-*)>' ~~ /^<$interpolate><$interpolate><$interpolate>$/,
    'Three separated variable interpoldations';
    ok '<(o_O)><(^_^)><(*-*)>' ~~ /^(<$interpolate>)+$/,'interpolated regex+';
}
