use Test;
use Spit::Compile;

plan 7;

ok compile(name => "Cmd || Cmd",Q{ my $a = Cmd<printf> || Cmd<echo> || Cmd<true> }).
   contains('exists printf'&'exists echo'), "Cmd junction always looks like exists cmd ||";

ok compile(name => "given inline", Q{
    my Pkg $nc = given $:os {
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

ok compile(
    name => 'inline now()', Q{
    now()
}).match(/now/,:g).elems <= 2, 'mentions now no more than twice';

nok compile(
    name => 'constant typecast', Q{
        constant $f = 'foo';
        if ~$f { say "win $_"; say "win $_" }
    }
).contains('if'|'='), ‘casted compile-time known str gets inlined’;

ok compile(
    name => 'cond return assignment', Q{
        constant $bar = "";
        my $a = $bar || "weee";
    }
).contains('a=weee');

ok compile(
    name => 'if False', Q{
        constant $foo = False;

        my $a = if $foo {
            "one";
        } else {
            "two"
        }
    }
).contains('a=two');
