use Test;
use Spit::Compile;

plan 3;

ok compile(name => "Cmd || Cmd",Q{ my $a = Cmd<printf> || Cmd<echo> || Cmd<true> }).
   contains('exists printf'&'exists echo'), "Cmd junction always looks like exists cmd ||";

ok compile(name => "given inline", Q{
    my Pkg $nc = given $*os {
        when Debian { 'netcat' }
        when RHEL   { 'nc' }
        default     { 'nc' }
    };
    note $nc;
}).contains('nc=netcat'), 'given block completely inline away';

ok compile(name => 'inlining nested blocks', Q{
              my $a =  {
                  if True {
                      ${true};
                      "foo";
                  };
              };
          }).contains('a="$(true; e foo)"');
