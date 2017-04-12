use Test;

plan 18;

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
