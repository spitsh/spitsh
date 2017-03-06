use Test;

plan 5;

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
