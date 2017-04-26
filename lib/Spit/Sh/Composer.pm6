unit class Spit::Sh::Composer;
use Spit::SAST;
need Spit::Exceptions;
need Spit::Constants;
need Spit::DependencyList;
need Spit::Metamodel;
need Spit::OptsParser;

multi reduce-block(SAST::Stmts:D $block) {
    if $block.children.all ~~ SAST::Empty {
        $block.stage3-node(SAST::Empty);
    } elsif $block.one-stmt -> $one-stmt {
        $one-stmt;
    } else {
        $block;
    }
}

multi reduce-block(SAST:D $non-block) { $non-block }

has $!deps = Spit::DependencyList.new;
has @.scaffolding;
has %.opts;
has $!os;
has %.clone-cache;
has $.no-inline;

method os {
    $!os ||= do {
        my $os-var = $*SETTING.lookup(SCALAR,'*os');
        self.walk($os-var);
        if (my $match = $os-var.match and  $os-var ~~ SAST::Block)
        or ($match = $os-var.assign.match and !$os-var.assign.compile-time) {
            SX.new(message => q<$*os definition too complex>,:$match).throw;
        }
        $os-var.assign.compile-time;
    }
}

method clone-node($node is rw) {
    return with $node.cloned;

    SX::CompStageNotCompleted.new(stage => 2,:$node).throw unless $node.stage2-done;

    with %!clone-cache{$node} {
        $node = $_;
    } else {
        $node = $_ = $node.clone(:cloned($node));
    }
}

proto method walk(SAST:D $sast is rw,|) {
    self.clone-node($sast);
    return if $sast.stage3-done;

    if $sast ~~ SAST::OSMutant and not $sast.mutated {
        $sast.mutate-for-os($.os);
        $sast.mutated = True;
    }

    if not $sast ~~ SAST::ClassDeclaration and $sast ~~ SAST::Children {
        for $sast.children {
            self.walk($_)
        }
    }

    $sast.stage3-done = True;
    {*}
}

multi method walk(SAST:D $ is rw) {}

multi method walk(SAST::CompUnit:D $THIS is rw) {
    self.add-scaffolding($_) for @!scaffolding;
    my $*CU = $THIS;
    self.include($THIS);
    $THIS.depends-on = $!deps;
}

multi method walk(SAST::ClassDeclaration:D $THIS is rw) {
    $THIS .= stage3-node(SAST::Empty);
}

multi method walk(SAST::While:D $THIS is rw) {
    with $THIS.cond.compile-time -> $cond {
        if not $cond {
            $THIS .= stage3-node(SAST::Empty);
            return;
        }
    }
}

method try-case($if) {
    my $can = True;
    my $common-topic;
    my \ENUM-HAS-MEMBER = (once tEnumClass.^find-spit-method('ACCEPTS'));
    my \ENUM-NAME       = (once tEnumClass.^find-spit-method: 'name');
    my \STR-MATCHES =     (once tStr.^find-spit-method: 'matches'|'match');
    my SAST::Regex:D @patterns;
    my SAST::Block:D @blocks;
    my SAST::Block   $default;

    my $cur = $if;
    while $cur and $can {
        my ($topic,$pattern);

        if $cur !~~ SAST::If {
            $default = $cur;
            $cur = Nil;
            last;
        }

        if (
            (my \cond = $cur.cond) ~~ SAST::Cmp && cond.sym eq 'eq'
                && (
                    $topic = cond[0];
                    $pattern = SAST::Regex.new(
                        patterns => { case => '{{0}}' },
                        placeholders => cond[1],
                        match => $cur.match,
                    );
                )
            or
            cond ~~ SAST::MethodCall && cond.declaration.identity === STR-MATCHES
                && (my $re = cond.pos[0]) ~~ SAST::Regex && $re.patterns<case>.defined
                && ($topic = cond[0]; $pattern = $re)
            or

            cond ~~ SAST::MethodCall && cond.declaration.identity === ENUM-HAS-MEMBER
                && (my $enum = cond[0].compile-time) ~~ Spit::Type
                && (
                    $topic = cond.pos[0].stage3-node(
                        SAST::MethodCall,
                        name => 'name',
                        declaration => ENUM-NAME,
                        cond.pos[0],
                    );
                    $pattern = SAST::Regex.new(
                        match    => $cur.match,
                        patterns => { case => $enum.^types-in-enum».name.join('|') }
                    )
                 )
            )
          {
              $common-topic //= $topic;
              if (given $common-topic {
                 when SAST::CompileTimeVal { $topic.val ===  .val }
                 when SAST::Var { $topic.declaration === .declaration }
                 when SAST::MethodCall {
                     $topic.declaration === .declaration === ENUM-NAME
                 }
              }) {
                  @patterns.push($pattern);
                  @blocks.push($cur.then);
              } else {
                  $can = False;
              }
              $cur = $cur.else;
          } else {
            $can = False;
        }
    }

    if $can and @patterns > 1 {
        $if.stage3-node: SAST::Case, in => $common-topic, :@blocks, :@patterns, :$default;
    }
}

multi method walk(SAST::If:D $THIS is rw,:$sub-if) {
    with $THIS.cond.compile-time -> $cond {
        if ?$cond {
            $THIS = $sub-if ?? $THIS.then !! reduce-block($THIS.then);
        } else {
            if $THIS.else <-> $else {
                $THIS = $else;
                self.walk($THIS);
            } else {
                $THIS .= stage3-node(SAST::Empty);
            }
        }
    } else {
        $THIS.else andthen self.walk($_,:sub-if);
    }

    if not $sub-if and $THIS ~~ SAST::If and self.try-case($THIS) -> $case {
        $THIS = $case;
    }
}

multi method walk(SAST::Ternary:D $THIS is rw) {
    given $THIS.cond.compile-time -> $ct {
        if $ct.defined {
            $THIS.switch: ($ct ?? $THIS.on-true !! $THIS.on-false);
        }
    }
}
# Type casts are only relevant in stage2
multi method walk(SAST::Cast:D $THIS is rw) {
    $THIS = $THIS[0];
}

multi method walk(SAST::Neg:D $THIS is rw) {
    if $THIS[0] ~~ SAST::Neg {
        $THIS = $THIS[0][0];
    } else {
        with $THIS[0].compile-time {
            $THIS .= stage3-node(SAST::BVal,val => !$_);
        }
    }
}

multi method walk(SAST::Negative:D $THIS is rw) {
    given $THIS[0] {
        when :compile-time {
            .val *= -1;
            $THIS = $_
        }
        when SAST::Negative { $THIS = $_[0] }
    }
}

multi method walk(SAST::Junction:D $THIS is rw) {
    my $a := $THIS[0];
    with $a.compile-time -> $ct-a {
        my $b := $THIS[1];
        if $THIS.dis {
            $THIS = $ct-a ?? $a !! $b;
        } else {
            $THIS = $ct-a ?? $b !! $a;
        }
    }
}

multi method walk(SAST::Var:D $THIS is rw where { $_ !~~ SAST::VarDecl }) {
    my $decl := $THIS.declaration;

    if $decl ~~ SAST::ConstantDecl {
        self.walk($decl); # Walk the declaration early so we can inspect it for inlining

        if $decl ~~ SAST::Stmts {
            $THIS.extra-depends.push($decl);
            $decl .= last-stmt;
        }

        if $decl.inline-value -> $inline {
            $THIS.switch: $inline;
        }

    } elsif $decl ~~ SAST::MaybeReplace and $decl.replace-with -> $val {
        $THIS.switch: do given $val {
            when SAST::Var {$val.gen-reference(match => $THIS.match,:stage2-done) }
            default { $val.deep-clone() }
        }
        $THIS.stage3-done = False;
        self.walk($THIS);
    }

}

multi method walk(SAST::ConstantDecl:D $THIS is rw) {
    callsame;
    if (my $block = $THIS.assign) ~~ SAST::Stmts:D {
        # Constant tucking:
        # constant $x = { side_effects(); get_value(); }
        # Can be changed to:
        # { side_effects(); constant $x = get_value() }
        # The latter is preferable for /bin/sh because side_effects() isn't run in a subshell
        my $ret := $block.returns;
        $THIS.assign = $ret.val;
        if $block.children > 1 {
            $ret = $THIS;
            $THIS = $block;
        }
    }
}

multi method walk(SAST::Given:D $THIS is rw) {
    if $THIS.topic-var.replace-with {
        $THIS .= block;
    }
}

multi method walk(SAST::VarDecl:D $THIS is rw where *.is-option ) {
    if %!opts{$THIS.bare-name} -> $val is copy {
        my $outer = $THIS.declared-in;
        if $val ~~ Spit::LateParse {
            $ = ?(require Spit::Compile <&compile>);
            my $cu = compile(
                $val.val,
                :target<stage1>,
                :$outer,name => $val.name
            );
            my $block = $cu.block;
            $val = $block;
        }
        my $*CURPAD = $outer;
        $val .= do-stage2($THIS.type);
        self.walk($val);
        $THIS.assign = $val;
    }
    callsame;
}

multi method walk(SAST::Elem:D $THIS is rw) {
    if $THIS.assign {
        $THIS .= stage2-node(
            SAST::MethodCall,
            name => 'set-pos',
            pos => ($THIS.index,$THIS.assign),
            $THIS.elem-of,
        );
    } else {
        $THIS .= stage2-node(
            SAST::MethodCall,
            name => 'at-pos',
            pos => $THIS.index,
            $THIS.elem-of,
        );
    }
    self.walk($THIS);
}

multi method walk(SAST::Eval:D $THIS is rw) {
    my %opts = $THIS.opts;
    %opts<os> //= SAST::Type.new(class-type => $.os,match => $THIS.match);


    # copy the old constant values into fresh SAST objects for use in the new
    # compilation
    for %opts.values <-> $opt {
        #TODO: roll this into its own routine
        my $match = $opt.match;
        $opt = do given $opt.compile-time {
            when Spit::Type {
                SAST::Type.new(class-type => $_,:$match);
            }
            when Int {
                SAST::IVal.new(val => $_,:$match);
            }
            when Str {
                SAST::SVal.new(val => $_,:$match);
            }
            when Bool {
                SAST::BVal.new(val => $_,:$match);
            }
            default {
                SX.new( match => $opt.match,
                        message => "can't use non-compile time value as arg to eval").throw;
            }
        }
    }

    $ = (require Spit::Compile <&compile>);
    $THIS .= stage3-node(
        SAST::SVal,
        val => compile(
            name => "eval_{$++}",
            $THIS.src.val,:%opts,
            outer => $THIS.outer,
            :one-block,
        ),
    );
}

multi method walk(SAST::Concat:D $THIS is rw) {
    with $THIS.compile-time {
        my $extra-depends := $THIS.children.map(*.extra-depends).flat;
        $THIS .= stage3-node: SAST::SVal,val => $_;
        $THIS.extra-depends.append($extra-depends);
    }
}

sub compile-time-infix($THIS is rw,\res-type) {
    with $THIS[0].compile-time -> $a {
        with $THIS[1].compile-time -> $b {
            my &op = do given $THIS.sym {
                when /<[<>]>/ { ::("\&infix:«$_»") }
                default     { ::("\&infix:<$_>") }
            }
            $THIS .= stage3-node(res-type, val => &op($a,$b) );
        }
    }
}

multi method walk(SAST::IntExpr:D $THIS is rw) {
    compile-time-infix($THIS,SAST::IVal);
}

multi method walk(SAST::Cmp:D $THIS is rw) {
    compile-time-infix($THIS,SAST::BVal);
}

# The things we can inline in CondReturns is limited. We can't have
# any ol shell command expresssion. The ones we can inline depend
# on whether their last value as it appears in the shell is the same
# as their original. See 'ef' and 'et' for why.
sub acceptable-in-cond-return($_,$original) {
    when SAST::Cmd {
        (not .write || .append || .pipe-in || .in) and
        (.nodes[*-1] andthen .identity === $original);
    }
    when SAST::MethodCall {
        (.pos[*-1] || .invocant) andthen .identity === $original;
    }
    when SAST::Call {
        .pos[*-1] andthen .identity === $original;
    }
    default { False }
}


multi method walk(SAST::CondReturn:D $THIS is rw) {

    with $THIS.Bool-call {
        my $orig = .invocant;
        self.walk($_, { acceptable-in-cond-return($_,$orig) } );
    }
    with ($THIS.Bool-call andthen .compile-time) {
        # We know the result of .Bool at compile time.
        # Test to see if the value should be inlined or if we should put a Bool in its place.
        if $_ === $THIS.when {
            $THIS .= val;
        } else {
            $THIS .= stage3-node(SAST::BVal,val => !$THIS.when);
        }
    }
}

multi method walk(SAST::OnBlock:D $THIS is rw) {
    with $THIS.chosen-block {
        $THIS = $_
    } else {
        $THIS .= stage3-node(
            SAST::Doom,
            exception => $THIS.make-new(
                SX::OnBlockNotDefOnOS,
                candidates => $THIS.os-candidates.map(*.key),
                :$.os,
            )
        )
    }
}


multi method walk(SAST::Stmts:D $THIS is rw) {
    if $THIS.returns -> $top-ret is raw {
        if (my $child-stmts = $top-ret.val) ~~ SAST::Stmts {
            use Spit::Util :remove;
            if $THIS.nodes.&remove(* =:= $top-ret) {
                $child-stmts.returns.ctx = $top-ret.ctx;
                $THIS.nodes.append($child-stmts.nodes);
            }
        }
    }

    $THIS .= &reduce-block if $THIS.auto-inline;
}

multi method walk(SAST::MethodCall:D $THIS is rw) {
    my \ENUMC_NAME = once tEnumClass.^find-spit-method('name');
    my \STR_BOOL = once tStr.^find-spit-method('Bool');
    my \ENUM_ACCEPTS = once tEnumClass.^find-spit-method('ACCEPTS');

    if $THIS.declaration === STR_BOOL
        and (my $ct = $THIS.invocant.compile-time).defined
    {
        $THIS .= stage3-node(SAST::BVal, val => ?$ct);
    }

    elsif $THIS.declaration === ENUMC_NAME
        and $THIS.invocant.compile-time -> $ct
    {
        $THIS .= stage3-node(SAST::SVal,val => $ct.name);
    }

    elsif $THIS.declaration === ENUM_ACCEPTS {
        my $enum := $THIS[0];
        my $candidate := $THIS.pos[0];

        if $candidate.compile-time -> $a {
            if $enum.compile-time -> Spit::Type $b {
                my $val = do given $a {
                    when Str { so $b.^types-in-enum».name.first($a) }
                    when Spit::Type { $a ~~ $b }
                };
                $THIS .= stage3-node(SAST::BVal,:$val);
            }
        }
    }
    else {
        callsame;
    }
}

multi  method walk(SAST::Call:D $THIS is rw, $accept = True) {
    return if $.no-inline;
    self.walk($THIS.declaration);

    if $THIS.declaration.chosen-block -> $block {
        if $block ~~ SAST::Block and not $block.ann<cant-inline> {
            # only inline routines with one child for now
            if $block.one-stmt <-> $last-stmt {
                if self.inline-call($THIS,$last-stmt) -> $replacement {
                    if $replacement ~~ $accept {
                        $THIS = $replacement;
                    }
                } else {
                    # If we find we can't inline it leave a marker so others
                    # don't bother trying.
                    $block.ann<cant-inline> = True;
                }
            }
        }
    } else {
        $THIS .= stage3-node(
            SAST::Doom,
            exception => $THIS.make-new(
                SX::RoutineNotDefOnOS,
                name => $THIS.name,
                |(class => $THIS.ostensible-type with $THIS.?invocant),
                candidates => $THIS.declaration.os-candidates.map(*.key),
                :$.os,
            )
        );
    }
}


method inline-value($inner,$outer,$_ is raw) {

    # if arg inside inner is a param use the corresponding arg from the original call
    when SAST::Var {
        my $decl := .declaration;
        return Nil if $_ === $decl; # don't wanna inline a variable declaration
        if $decl ~~ SAST::PosParam {
            $outer.pos[$decl.ord];
        } elsif $decl ~~ SAST::NamedParam {
            $outer.named{$decl.name} || $outer.stage3-node(SAST::BVal,val => False);
        } elsif $decl ~~ SAST::Invocant {
            $outer.invocant;
        } else {
            #XXX: since we only inline blocks with 1 node in them this should be ok
            # not $inner.deep-first(* =:= $decl)
            $_;
        }
    }
    # if arg inside inner is a blessed value, try inlining the value
    when SAST::Blessed|SAST::Neg {
        if self.inline-value($inner,$outer,.children[0]) -> $val {
            .children[0] = $val;
            # because we're changing child of a rather than the node itself
            # we'll need to re-walk it so it has a chance to re-optimize itself.
            .stage3-done = False;
            self.walk($_);
            $_;
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
            self.inline-value($inner,$outer,$_);
        };
        if @inlined.all.defined {
            $*char-count += $char-count;
            .children = @inlined;
            $_;
        }
    }
    default {
        Nil
    }
}

subset ChildSwapInline of SAST:D
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

    my $replacement = $inner.deep-clone;

    my $*char-count = 0;
    my $max = 10; #TODO: allow customization of this
    for $replacement.children -> $try-switch is raw {
        if self.inline-value($replacement,$outer,$try-switch) -> $switch {
            return if $*char-count > $max;
            $try-switch.switch: $switch;
        } else {
            return
        }
    }
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

method add-scaffolding(SAST::Dependable:D $dep is rw)  {
    my $before = $dep;
    self.walk($dep);
    $!deps.add-scaffolding($dep, name => $before.?name);
    for $dep.child-deps {
        self.add-scaffolding($_);
    }
}

multi method include(SAST:D $sast) {
    $sast.included && return False;
    $sast.included = True;

    if $sast ~~ SAST::Children and not $sast ~~ SAST::ClassDeclaration {
        self.include($_) for $sast.children;
    }

    for $sast.all-depends {
        self.walk($_);
        .depended = True;
        if ! .dont-depend {
            self.include($_) && $!deps.add-dependency($_);
        }
    }
    return True;
}

multi method include(SAST::PhaserBlock:D $phaser-block is rw) {
    self.include($phaser-block.block);
    $*CU.phasers[$phaser-block.stage].push($phaser-block.block);
    $phaser-block .= stage3-node(SAST::Empty,:included);
}
