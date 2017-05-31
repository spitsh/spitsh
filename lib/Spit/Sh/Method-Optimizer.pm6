need Spit::SAST;
# A place to put optimizations for specific methods.
# Speeds up optimization by having the type as the first argument
# to method-optimize (so it only checks for optimizable methods on types
# that could possibly have those methods).
unit role Method-Optimizer;

use Spit::Metamodel;

# cache for method declarations
has $!ENUMC-ACCEPTS;
has $!ENUMC-NAME;
has $!STR-BOOL;
has $!STR-MATCH;
has $!STR-SUBST-EVAL;
has $!JSON-AT-POS;
has $!JSON-AT-KEY;
has $!JSON-AT-PATH;
has $!JSON-LIST;
has $!JSON-KEYS;
has $!JSON-VALUES;

method ENUMC-ACCEPTS  { $!ENUMC-ACCEPTS  //= tEnumClass.^find-spit-method: 'ACCEPTS' }
method ENUMC-NAME     { $!ENUMC-NAME     //= tEnumClass.^find-spit-method: 'name'    }
method STR-MATCHES    { $!STR-MATCH      //= tStr.^find-spit-method:       'match'   }
method STR-BOOL       { $!STR-BOOL       //= tBool.^find-spit-method:      'Bool'    }
method STR-SUBST-EVAL { $!STR-SUBST-EVAL //= tStr.^find-spit-method:    'subst-eval' }
method JSON-AT-POS    { $!JSON-AT-POS    //= tJSON.^find-spit-method:      'at-pos'  }
method JSON-AT-KEY    { $!JSON-AT-KEY    //= tJSON.^find-spit-method:      'at-key'  }
method JSON-AT-PATH   { $!JSON-AT-PATH   //= tJSON.^find-spit-method:      'at-path' }
method JSON-LIST      { $!JSON-LIST      //= tJSON.^find-spit-method:      'List'    }
method JSON-KEYS      { $!JSON-KEYS      //= tJSON.^find-spit-method:      'keys'    }
method JSON-VALUES    { $!JSON-VALUES    //= tJSON.^find-spit-method:      'values'  }

# Dirty way of creating a synthetic SAST::SVal.
# Our fake Match objects shouldn't matter because we
sub sval(Str $str) {
    SAST::SVal.new(
        val => $str,
        match => Match.new,
    );
}

# Each method-optimize is responsible for calling self.walk($THIS.invocant).
# It isn't done automatically so we can inspect JSON methods and optimize them into
# one single call to jq before .walk'ing them.
multi method method-optimize(tJSON, $THIS is rw, $decl is copy) {
    my $cur = $THIS;
    my @pos;
    while my $at-key = ($decl === self.JSON-AT-KEY) or
          my $at-pos = ($decl === self.JSON-AT-POS) or
          my $list   = ($decl  === self.JSON-LIST)  or
          my $keys   = ($decl === self.JSON-KEYS)   or
                       ($decl === self.JSON-VALUES)
    {
        my $arg := $cur.pos[0];
        self.walk($arg) if $arg;
        my $path := @pos[0];
        $path //= ($arg || $cur).stage3-node(SAST::Concat);

        if $at-key {
            with $arg.compile-time {
                when /^<.ident>$/ {
                    $path.unshift(sval('.'),$arg)
                }
                default {
                                # escape " and \"
                    $path.unshift: sval('["'), sval(S!'\\'<?before '"'>|'"'!\\$/!), sval('"]')
                }
            } else {
                my $name = (97 + ((@pos.elems - 1)/3).Int).chr;
                $path.unshift: sval(“[\$$name]”);
                @pos.append: sval('--arg'), sval($name), $arg;
            }
        }
        elsif $at-pos {
            $path.unshift(sval('['), $arg, sval(']'));
        }

        elsif $list {
            $path.unshift(sval('[]'));
        }
        elsif $keys {
            $path.unshift(sval('|keys[]'));
        }
        else {
            $path.unshift(sval('|values[]'));
        }

        $cur = $cur.invocant;
        if $cur ~~ SAST::MethodCall:D {
            $decl = $cur.declaration.identity;
        } else {
            $decl = Nil;
        }
    }

    if @pos {
        @pos[0].unshift(sval('.')) unless @pos[0][0].val eq '.';
        $THIS .= stage2-node(
            SAST::MethodCall,
            name => 'at-path',
            declaration => self.JSON-AT-PATH,
            :@pos,
            $cur,
        );
        self.walk($THIS.invocant);
        True;
    }
    else { callsame }
}

multi method method-optimize(tEnumClass, $THIS is rw, $decl) {
    self.walk($THIS.invocant);

    if $decl === self.ENUMC-NAME
       and $THIS.invocant.compile-time -> $ct
    {
        $THIS .= stage3-node(SAST::SVal,val => $ct.name);
        return False;
    }

    elsif $decl === self.ENUMC-ACCEPTS
    {
        my $enum := $THIS[0];
        my $candidate := $THIS.pos[0];

        if $candidate.compile-time -> $a {
            if $enum.compile-time -> Spit::Type $b {
                my $val = do given $a {
                    when Str { so $b.^types-in-enum».name.first($a) }
                    when Spit::Type { $a ~~ $b }
                };
                $THIS .= stage3-node(SAST::BVal,:$val);
                return False;
            }
        }
    }
    else { callsame }
    True;
}

multi method method-optimize(tStr, $THIS is rw, $decl){
    self.walk($THIS.invocant);
    if $decl === self.STR-BOOL
       and (my $ct = $THIS.invocant.compile-time).defined
    {
        $THIS .= stage3-node(SAST::BVal, val => ?$ct);
        False
    } else {
        True;
    }
}

multi method method-optimize($,$THIS,$) { self.walk($THIS.invocant); True }
