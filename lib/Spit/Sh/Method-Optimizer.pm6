need Spit::SAST;
use JSON::Tiny;
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
has $!STR-JSON;
has $!STR-MATCH;
has $!STR-SUBST-EVAL;
has $!LIST-JOIN;
has $!JSON-AT-POS;
has $!JSON-AT-KEY;
has $!JSON-AT-PATH;
has $!JSON-LIST;
has $!JSON-KEYS;
has $!JSON-VALUES;
has $!JSON-SET-POS;
has $!JSON-SET-KEY;
has $!JSON-SET-PATH;
has $!JSON-BOOL-PATH;
has $!JSON-MERGE;
has $!JSON-ACCEPTS;
has $!JSON-AT-LIST-POS;

method ENUMC-ACCEPTS  { $!ENUMC-ACCEPTS  //= tEnumClass.^find-spit-method: 'ACCEPTS' }
method ENUMC-NAME     { $!ENUMC-NAME     //= tEnumClass.^find-spit-method: 'name'    }
method STR-MATCHES    { $!STR-MATCH      //= tStr.^find-spit-method:       'match'   }
method STR-BOOL       { $!STR-BOOL       //= tStr.^find-spit-method:       'Bool'    }
method STR-JSON       { $!STR-JSON       //= tStr.^find-spit-method:      'JSON'    }
method STR-SUBST-EVAL { $!STR-SUBST-EVAL //= tStr.^find-spit-method:    'subst-eval' }
method LIST-JOIN      { $!LIST-JOIN      //= tList.^find-spit-method:      'join'    }
method JSON-AT-POS    { $!JSON-AT-POS    //= tJSON.^find-spit-method:      'at-pos'  }
method JSON-AT-KEY    { $!JSON-AT-KEY    //= tJSON.^find-spit-method:      'at-key'  }
method JSON-AT-PATH   { $!JSON-AT-PATH   //= tJSON.^find-spit-method:      'at-path' }
method JSON-LIST      { $!JSON-LIST      //= tJSON.^find-spit-method:      'List'    }
method JSON-KEYS      { $!JSON-KEYS      //= tJSON.^find-spit-method:      'keys'    }
method JSON-VALUES    { $!JSON-VALUES    //= tJSON.^find-spit-method:      'values'  }
method JSON-SET-POS   { $!JSON-SET-POS   //= tJSON.^find-spit-method:      'set-pos' }
method JSON-SET-KEY   { $!JSON-SET-KEY   //= tJSON.^find-spit-method:      'set-key' }
method JSON-SET-PATH  { $!JSON-SET-PATH  //= tJSON.^find-spit-method:      'set-path'}
method JSON-BOOL-PATH { $!JSON-BOOL-PATH  //= tJSON.^find-spit-method:      'bool-path' }
method JSON-MERGE     { $!JSON-MERGE     //= tJSON.^find-spit-method:      'merge'   }
method JSON-ACCEPTS   { $!JSON-ACCEPTS   //= tJSON.^find-spit-method:      'ACCEPTS' }
method JSON-AT-LIST-POS { $!JSON-AT-LIST-POS //= tJSON.^find-spit-method: 'at-list-pos'  }

# Dirty way of creating a synthetic SAST::SVal.
# Our fake Match objects shouldn't matter because we
sub sval(Str $str) {
    SAST::SVal.new(
        val => $str,
        match => Match.new,
    );
}

sub jq-arg($arg is raw, @pos is raw) {
    my $name = (97 + ((@pos.elems - 1)/3).Int).chr;
    @pos.append: sval('--arg'), sval($name), $arg;
    $name;
}

sub json-key($arg is raw, $path is raw, @pos is raw) {
    with $arg.compile-time {
        when /^<.ident>$/ {
            $path.unshift(sval('.'),$arg)
        }
        default {
            # escape " and \"
            $path.unshift: sval('['), sval(.&to-json), sval(']')
        }
    } else {
        my $name = jq-arg($arg, @pos);
        $path.unshift: sval(“[\$$name]”);
    }
}

sub json-value($value is raw, $path is raw, @pos is raw) {
    if $value.type ~~ tJSON {
        $path.push: sval('='), $value;
    } else {
        with $value.compile-time {
            $path.push: sval '=' ~ .&to-json;
        } else {
            my $name = jq-arg($value, @pos);
            $path.push: sval "=\$$name";
        }
    }
}

# Each method-optimize is responsible for calling self.walk($THIS.invocant).
# It isn't done automatically so we can inspect JSON methods and optimize them into
# one single call to jq before .walk'ing them.

multi method method-optimize(tJSON, $THIS is rw, $decl is copy) {
    my $cur = $THIS;
    # The arguments to jq
    my @pos;
    # path is the jq path like jq '.foo.bar[0]'
    my $path := @pos[0];
    my $end-call = 'at';
    while $decl and $decl.class-type ~~ tJSON {
        my $arg := $cur.pos[0];
        self.walk($arg) if $arg;
        $path //= ($arg || $cur).stage2-node(SAST::Concat);

        if $decl === self.JSON-AT-KEY {
            json-key($arg,$path,@pos);
        }
        elsif $decl === self.JSON-AT-POS {
            $path.unshift(sval('['), $arg, sval(']'));
        }
        elsif $decl === self.JSON-AT-LIST-POS {
            my $join = $arg.stage2-node(
                SAST::MethodCall,
                name => 'join',
                declaration => self.LIST-JOIN,
                pos => sval(','),
                $arg,
            );
            self.walk($join);
            $path.unshift(sval('|[.['),$join,sval(']]'));
        }
        elsif $decl === self.JSON-LIST {
            $path.unshift(sval('[]'));
        }
        elsif $decl === self.JSON-KEYS {
            $path.unshift(sval('|keys[]'));
        }
        elsif $decl === self.JSON-VALUES {
            $path.unshift(sval('|values[]'));
        }
        elsif $decl === self.JSON-SET-POS {
            $end-call = 'set';
            my $value := $cur.pos[1];
            self.walk($value);
            # note unshift vs is irrelevant here because set-*
            # will always be first
            $path.unshift(sval('['), $arg, sval(']'));
            json-value($value,$path,@pos);
        }
        elsif $decl === self.JSON-SET-KEY {
            $end-call = 'set';
            my $value := $cur.pos[1];
            self.walk($value);
            json-key($arg, $path, @pos);
            json-value($value, $path, @pos);
        }
        elsif $decl === self.JSON-MERGE {
            # need | if merge isn't the first thing we visit
            $path.unshift: sval(' * '), $arg, (sval('|') if $path.elems)
        }
        elsif $decl === self.JSON-ACCEPTS {
            $end-call = 'bool';
            $path.unshift: sval(' == '), $arg;
        } else {
            $decl = Nil;
            next;
        }

        $cur = $cur.invocant;
        if $cur ~~ SAST::MethodCall:D {
            $decl = $cur.declaration.identity;
        } else {
            $decl = Nil;
        }
    }

    if $path.elems {
        # The first thing should always be '.', but not every
        # start with it so we just add it at the beggining if
        # it's not there.
        $path.unshift(sval('.')) unless $path[0].val eq '.';
        self.walk($path);
        my $method = do given $end-call {
            when 'at'   { self.JSON-AT-PATH }
            when 'set'  { self.JSON-SET-PATH }
            when 'bool' { self.JSON-BOOL-PATH }
        };
        $THIS .= stage2-node(
            SAST::MethodCall,
            name => $method.name,
            declaration => $method,
            :@pos,
            $cur,
        );
        self.walk($THIS.invocant);
        self.walk($THIS);
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
    my $ct = $THIS.invocant.compile-time;
    return True unless $ct.defined;

    if $decl === self.STR-BOOL
    {
        $THIS .= stage3-node(SAST::BVal, val => ?$ct);
        False
    }
    elsif $decl === self.STR-JSON {
        $THIS .= stage3-node(SAST::SVal, val => $ct.&to-json);
        False;
    }
    else {
        True;
    }
}

multi method method-optimize(tList, $THIS is rw, $decl) {
    self.walk($THIS.invocant);
    if $decl === self.LIST-JOIN
       and (my $ct = $THIS.invocant.compile-time).defined
       and (my $joiner = $THIS.pos[0].compile-time).defined
    {
        $THIS .= stage3-node(SAST::SVal, val => $ct.join($joiner));
        False
    }
    else {
        True
    }
}

multi method method-optimize($,$THIS is rw,$) { self.walk($THIS.invocant); True }
