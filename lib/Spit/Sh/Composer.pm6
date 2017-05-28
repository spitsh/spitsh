unit class Spit::Sh::Composer;
use Spit::SAST;
need Spit::Exceptions;
need Spit::Constants;
need Spit::DependencyList;
use Spit::Metamodel;
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

# cache for method declarations
has $!ENUMC-ACCEPTS;
has $!ENUMC-NAME;
has $!STR-BOOL;
has $!STR-MATCH;
has $!STR-SUBST-EVAL;

method ENUMC-ACCEPTS { $!ENUMC-ACCEPTS //= tEnumClass.^find-spit-method: 'ACCEPTS' }
method ENUMC-NAME    { $!ENUMC-NAME //= tEnumClass.^find-spit-method: 'name' }
method STR-MATCHES   { $!STR-MATCH //= tStr.^find-spit-method: 'match' }
method STR-BOOL      { $!STR-BOOL //= tBool.^find-spit-method: 'Bool' }
method STR-SUBST-EVAL     { $!STR-SUBST-EVAL //= tStr.^find-spit-method: 'subst-eval' }

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
        for $sast.auto-compose-children {
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

multi method walk(SAST::Cmd:D $THIS is rw) {
    my @nodes := $THIS.nodes;
    for @nodes.kv -> $i, $_ {
        when SAST::List {
            @nodes.splice($i,1,.children) unless .itemize;
        }
    }

    if ($THIS.pipe-in andthen .is-invocant) -> $invocant {
        # vote to pipe the invocant
        $invocant.vote-pipe-yes;
    }
}

multi method walk(SAST::While:D $THIS is rw) {
    my $*no-pipe = True;
    self.walk($THIS);
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
            cond ~~ SAST::MethodCall && cond.declaration.identity === self.STR-MATCHES()
            && (my $re = cond.pos[0]) ~~ SAST::Regex && $re.patterns<case>.defined
            && ($topic = cond[0]; $pattern = $re)
            or

            cond ~~ SAST::MethodCall && cond.declaration.identity === self.ENUMC-ACCEPTS()
            && (my $enum = cond[0].compile-time) ~~ Spit::Type
            && (
                $topic = cond.pos[0].stage3-node(
                    SAST::MethodCall,
                    name => 'name',
                    declaration => self.ENUMC-NAME,
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
                       $topic.declaration === .declaration === self.ENUMC-NAME
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

    }

    elsif $decl ~~ SAST::MaybeReplace  {
        if $decl.replace-with -> $val {
            $THIS.switch: do given $val {
                when SAST::Var {$val.gen-reference(match => $THIS.match,:stage2-done) }
                default { $val.deep-clone() }
            }
            $THIS.stage3-done = False;
            self.walk($THIS);
        } else {
            $decl.add-ref($THIS);
        }
    }

    elsif $decl ~~ SAST::Invocant  {
        # Pipe voting:
        # -------------
        # Make sure the MethodDeclaration.invocant is cloned so we can start
        # counting on its $.pipe-vote attribute.
        self.walk($decl);
        # $.pipe-vote > 0 means it will get piped.
        without $decl.pipe-vote {
            $decl.start-pipe-vote;
        }
        # If the the no vote here is balanced by a yes vote
        # then it will get piped. Any further no votes will mean
        # no piping (only the first yes vote is counted).
        $decl.vote-pipe-no;
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

constant @eval-placeholders =
"\c[
bouquet, cherry blossom, white flower, rosette, rose, wilted flower, hibiscus,
sunflower, blossom, tulip, kiss mark, heart with arrow, beating heart,
broken heart, two hearts, sparkling heart, growing heart, blue heart, green heart ,
yellow heart, purple heart, black heart, heart with ribbon, revolving hearts,
heart decoration, love letter
]".comb;


multi method walk(SAST::Eval:D $THIS is rw) {
    my %opts = $THIS.opts;
    %opts<os> //= SAST::Type.new(class-type => $.os,match => $THIS.match);

    my @placeholders = @eval-placeholders.pick(*);

    for %opts.kv -> $name, $opt is rw {
        my $ct = $opt.compile-time;
        if  $ct or $ct.defined {
            # copy the old constant values into fresh SAST objects for use in the new
            # compilation with sastify
            $opt = sastify($ct, match => $opt.match);
        } else {
            # Runtime value. We we compile an emoji placeholder characer which will
            # be replaced with the runtime value later.
            $opt = SAST::EvalArg.new(
                type => $opt.type,
                match => $opt.match,
                placeholder => @placeholders.shift,
                value => $opt,
            )
        }
    }

    $ = (require Spit::Compile <&compile>);
    my $compiled = $THIS.stage3-node(
        SAST::SVal,
        val => compile(
            name => "eval_{$++}",
            $THIS.src.val,
            :%opts,
            outer => $THIS.outer,
            :one-block,
        ),
    );

    if list %opts.values.grep(SAST::EvalArg) -> @runtime-args {
        for @runtime-args -> $rt-arg {
           $compiled = $rt-arg.stage2-node(
                SAST::MethodCall,
                name => 'subst-eval',
                declaration => self.STR-SUBST-EVAL,
                match => $rt-arg.match,
                $compiled,
                pos => (
                    $rt-arg.stage2-node(SAST::SVal, val => $rt-arg.placeholder),
                    $rt-arg.value,
                )
            );
        }
        self.walk($compiled);
    }
    $THIS = $compiled;
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

# Checks that the thing the that the .Bool call was inlined to has the
# invocant as the last argument (and no weird stuff that shouldn't
# exist in a shell call). This is so:
# et Bool "thing"
# doesn't inline to:
# et other_method | something
# A rather complex solution, but necessary for now.
sub acceptable-in-cond-return($_,$orig-invocant) {
    when SAST::Cmd {
        (not .write || .append || .pipe-in || .in) and
        (.nodes[*-1] andthen .identity === $orig-invocant);
    }
    when SAST::MethodCall {
        (.pos[*-1] || .invocant) andthen .identity === $orig-invocant;
    }
    when SAST::Call {
        .pos[*-1] andthen .identity === $orig-invocant;
    }
    default { False }
}


multi method walk(SAST::CondReturn:D $THIS is rw) {

    with $THIS.Bool-call {
        self.walk(my $orig-invocant := .invocant);
        self.walk($_, { acceptable-in-cond-return($_, $orig-invocant.identity) } );
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

multi method walk(SAST::Blessed:D $THIS is rw) {
    $THIS.switch: $THIS[0], :!force-ctx;
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
    self.walk($THIS.declaration);

    my \ident = $THIS.declaration.identity;

    if ident === self.STR-BOOL
        and (my $ct = $THIS.invocant.compile-time).defined
    {
        $THIS .= stage3-node(SAST::BVal, val => ?$ct);
    }

    elsif ident === self.ENUMC-NAME
        and $THIS.invocant.compile-time -> $ct
    {
        $THIS .= stage3-node(SAST::SVal,val => $ct.name);
    }

    elsif ident === self.ENUMC-ACCEPTS {
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
    my $decl := $THIS.declaration;
    self.walk($decl);

    # Add defaults to the call for missing args and then walk them
    self.walk($_) for $THIS.fill-in-defaults;

    return if $.no-inline;

    if $decl.chosen-block -> $block {
        if $block ~~ SAST::Block and not $block.ann<cant-inline> and not $decl.no-inline {
            # only inline routines with one child for now
            if $block.one-stmt <-> $last-stmt {
                if self.inline-call($THIS,$last-stmt) -> $replacement {
                    if $replacement ~~ $accept {
                        $THIS.switch: $replacement;
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
                |(class => $THIS.ostensible-type if $THIS ~~ SAST::MethodCall),
                candidates => $decl.os-candidates.map(*.key),
                :$.os,
            )
        );
    }

    # When we get here all inlining and replacement is done.
    # There's no chance of it disappearing anymore so time to vote.
    if $THIS ~~ SAST::MethodCall {
        # Is the call's invocant the $self of the method block we're in?
        if (my $invocant = ($THIS.invocant andthen .is-invocant))
           # AND should the method we're calling be piped to?
           and ($THIS.declaration.invocant andthen .piped)
        {
            # If so, vote for piping the method we're in's $self
            $invocant.vote-pipe-yes;
        }
    }
}


method inline-value($inner,$outer,$_ is raw) {

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
        if self.inline-value($inner,$outer,.children[0]) -> $val {
            # clone because we don't want to mutate a node from the inner call
            my $clone = .clone;
            $clone.children[0] = $val;
            # Because we're changing child of node a rather than the
            # node itself we re-walk it because with the new child
            # further optimizations might be possible.
            $clone.stage3-done = False;
            self.walk($clone);
            $clone;
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
            # clone because we don't want to mutate a node from the inner call
            my $clone = .clone;
            $clone.children = @inlined;
            $clone;
        }
    }
    default {
        Nil
    }
}

subset ChildSwapInline of SAST::Children:D
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
    if $replacement ~~ SAST::Cmd and $outer.ctx === tAny and $outer.type ~~ tStr {
        $replacement.silence = True;
    }
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
