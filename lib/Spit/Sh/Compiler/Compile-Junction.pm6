need Spit::SAST;
use Spit::Metamodel;
use Spit::Sh::ShellElement;

unit role Compile-Junction;
#!Junction
multi method assign($var,SAST::Junction:D $j) {
    # is this a $a ||= "foo" ?
    my $or-equals = do given $j[0] {
        $_ ~~ SAST::CondReturn
        and .when == True # ie || not &&
        and $var.uses-Str-Bool # they Boolify using Str.Bool
        and .val.?declaration === $var.declaration # var refers to same thing
    }
    if $or-equals and $var.type ~~ tStr {
        my $name = self.gen-name($var);
        '${',$name,':=', |self.arg($j[1]).in-param-expansion,'}';
    } else {
        nextsame;
    }
}
multi method node(SAST::Junction:D $_) {
    |self.cond($_[0]), (.dis ?? ' || ' !! ' && '),|self.node($_[1])
}

multi method cond(SAST::Junction:D $_,:$tight) {
    ('{ ' if $tight ),
    |self.cond($_[0]), (.dis ?? ' || ' !! ' && '),|self.cond($_[1],:tight),
    ('; }' if $tight );
}

multi method arg(SAST::Junction:D $_) {
    with self.try-param-substitution($_) {
        .return;
    } else {
        nextsame;
    }
}

method try-param-substitution(SAST::Junction:D $junct) {
    my \LHS = $junct[0];
    my \RHS = $junct[1];
    if LHS ~~ SAST::CondReturn and LHS.val ~~ SAST::Var and LHS.val.uses-Str-Bool {
        dq '${',
        self.gen-name(LHS.val),
        (LHS.when ?? ':-' !! ':+'),
        self.arg(RHS).in-param-expansion,
        '}';
    }
}

multi method cap-stdout(SAST::Junction:D $_) { self.compile-junction($_) }

# Mimicking perl-like junctions in a stringy context (|| &&) in shell is tricky.
# This:
#     my $a = $foo || $bar;
# becomes:
#     a="$( test "$foo" && echo "$foo" || echo "$bar"; )"
# And that's the simplest case.
# We simplify the above by wrapping terms that conditionally need to return
# with SAST::CondReturn. Then delegate to helper functions "et" and "ef"
# (echo-when-true and echo-when-false). So the above becomes:
#     et() { "$1" "$2" && echo "$2"; }
#     a="$(et test "$foo" || echo "$bar" )"
#
multi method compile-junction(SAST::Junction:D $junct,:$junct-ctx,:$on-rhs) {
    with self.try-param-substitution($junct) {
        self.scaf('e'),' ',|$_;
    } else {
        my \LHS = $junct[0];
        my \RHS = $junct[1];
        my $junct-char := ($junct.dis ?? ' || ' !! ' && ');
        ('{ ' if $on-rhs),
        |self.compile-junction(LHS,junct-ctx => $junct.LHS-junct-ctx),
        $junct-char,
        |self.compile-junction(RHS,junct-ctx => $junct.RHS-junct-ctx,:on-rhs),
        (';}' if $on-rhs)
    }
}

multi method compile-junction($node,:$junct-ctx) {
    given $junct-ctx {
        when NEVER-RETURN { |self.cond($node) }
        default { |self.cap-stdout($node) }
    }
}
#!CondReturn
multi method cap-stdout(SAST::CondReturn:D $_) {
    if .when === True  and !.Bool-call {
        '{ ',|self.cond(.val), ' && ',self.scaf('e'), ' 1;',' }';
    } elsif .when === False and .val.uses-Str-Bool or !.Bool-call {
        # Special case shell optimization!!!
        # $(test "$foo" || { echo "$foo" && false; }  && echo "$bar")
        # can be reduced-to: (test "$foo" || echo "$bar")
        self.cond(.val);
    } else {
        self.scaf(.when ?? 'et' !! 'ef'),' ',|self.cond(.Bool-call)
    }
}

multi method cond(SAST::CondReturn:D $_,|c) { self.cond(.val,|c) }
