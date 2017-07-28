need Spit::SAST;
need Spit::Constants;
use Spit::Metamodel;

unit role Call-Inliner;

method inline-value($outer,$_ is raw) {

    # if arg inside inner is a param use the corresponding arg from the original call
    when SAST::Var {
        my $decl := .declaration;
        return Nil if $_ === $decl; # don't wanna inline a variable declaration
        if $decl ~~ SAST::PosParam {
            if $decl.slurpy {
                with $outer.pos[$decl.ord] {
                    .stage3-node: SAST::List, |$outer.pos[$decl.ord..*];
                } else {
                    $outer.stage3-node: SAST::Empty;
                }
            } else {
                $outer.pos[$decl.ord];
            }
        } elsif $decl ~~ SAST::NamedParam {
            $outer.named{$decl.name} || $outer.stage3-node(SAST::BVal,val => False);
        } elsif $decl ~~ SAST::Invocant {
            $outer.invocant;
        } else {
            #XXX: A variable that isn't a param ref. Pass it through
            # and hope that it's something from the outer lexical scope (for now).
            $_;
        }
    }
    # if arg inside inner is a blessed value, try inlining the value
    when SAST::Neg {
        if self.inline-value($outer,.children[0]) -> $val {
            # clone because we don't want to mutate a node from the inner call
            my $clone = .clone;
            $clone.children[0] = $val;
            # Because we're changing child of node a rather than the
            # node itself we re-walk it because with the new child
            # further optimizations might be possible.
            $clone.stage3-done = False;
            self.walk($clone);
            $clone;
        } else {
            Nil
        }
    }
    when *.compile-time.defined {
        $*char-count += .compile-time.chars;
        $_;
    }

    when SAST::Concat {
        my int $char-count = 0;
        my @inlined = .children.map: {
            .compile-time andthen $char-count += ($_ ~~ Bool ?? (.so ?? 1 !! 0) !! .Str.chars);
            self.inline-value($outer,$_);
        };
        if @inlined.all.defined {
            $*char-count += $char-count;
            # clone because we don't want to mutate a node from the inner call
            my $clone = .clone;
            $clone.children = @inlined;
            $clone;
        } else {
            Nil
        }
    }
    default {
        Nil
    }
}

my subset ChildSwapInline of SAST::Children:D
       where SAST::Call|SAST::Cmd|SAST::Increment|SAST::Neg|SAST::Cmp|SAST::Concat;

# CONSIDER:
#   {
#    sub foo($a) { say($a) }
#    foo "baz";
#   }
# 'foo("baz")' is the $outer call, 'say($a)' is the $inner call.
# We inline by switching the outer SAST::Call out for a modified clone of the inner SAST::Call.
# We can do this with a bunch of other nodes as well.
multi method inline-call(SAST::Call:D $outer,ChildSwapInline $inner) {
    # Can't inline is rw methods yet. Probs need to redesign it before we can.
    return if ($outer ~~ SAST::MethodCall) && $outer.declaration.rw;

    # No need to deep-clone. .inline-value will opportunistically
    # clone when necessary.
    my $replacement = $inner.clone;

    my $*char-count = 0;
    my $max = 10; #TODO: allow customization of this
    my @switch-list;
    for $replacement.children -> $try-switch is raw {
        if self.inline-value($outer,$try-switch) -> $switch {
            return if $*char-count > $max;
            @switch-list.push: ($try-switch, $switch);
        } else {
            return
        }
    }
    # If we got to here do the inline replacement
    $_[0].switch: $_[1] for @switch-list;

    # Re-walk replacement. It's possible after inlining further optimizations
    # can be done.
    $replacement.stage3-done = False;
    self.walk($replacement);

    $replacement;
}

multi method inline-call(SAST::Call:D $outer,SAST::CompileTimeVal:D $_) { $_ }

multi method inline-call(SAST::Call:D $outer,$) { Nil }
multi method inline-call(SAST::Call:D $outer,SAST::Var:D $inner) {
    given $inner.declaration {
        when SAST::Invocant   { $outer[0] }
        when SAST::PosParam   { $outer.pos[.ord] }
        when SAST::NamedParam { $outer.named{.name} || $outer.stage3-node(SAST::BVal, val => False) }
        default { $inner }
    }
}
multi method inline-call(SAST::Call:D $outer, SAST::Empty $inner) {
    $inner.clone;
}
