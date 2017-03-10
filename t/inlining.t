use Test;
use Spit::Compile;

plan 1;

ok compile(name => "Cmd || Cmd",Q{ my $a = Cmd<printf> || Cmd<echo> || Cmd<true> }).
   contains('exists printf'&'exists echo'), "Cmd junction always looks like exists cmd ||";
