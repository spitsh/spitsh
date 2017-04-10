unit class Spit::Sh::Composer;
use Spit::SAST;
need Spit::Exceptions;
need Spit::Parser::P5Regex;
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

    my $save = $sast;
    {*}
    $save.stage3-done = True;
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

    if $THIS.is-option and not $decl.assign and not %!opts{$THIS.bare-name} {
        SX::RequiredOption.new(
            name => $THIS.bare-name,
            match => $THIS.match).throw;
    }

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
        $THIS = do given $val {
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
            $THIS.src.val,:%opts,outer => $THIS.outer
        ),
    );
}

multi method walk(SAST::Concat:D $THIS is rw) {
    if $THIS.children».compile-time».defined.all {
        # TODO fold as many as possible
        $THIS .= stage3-node(SAST::SVal,val => $THIS.children».compile-time.join);
    }
}

sub compile-time-infix($THIS is rw,\res-type) {
    with $THIS[0].compile-time -> $a {
        with $THIS[1].compile-time -> $b {
            $THIS .= stage3-node(res-type, val => ::('&infix:<' ~ $THIS.sym ~ '>')($a,$b) );
        }
    }
}

multi method walk(SAST::IntExpr:D $THIS is rw) {
    compile-time-infix($THIS,SAST::IVal);
}

multi method walk(SAST::Cmp:D $THIS is rw) {
    compile-time-infix($THIS,SAST::BVal);
}

multi method walk(SAST::EnumCmp:D $THIS is rw) {
    if $THIS.check.compile-time -> $a {
        if $THIS.enum.compile-time -> Spit::Type $b {
            my $val = do given $a {
                when Str { so $b.^types-in-enum».name.first($a) }
                when Spit::Type { $a ~~ $b }
            };
            $THIS .= stage3-node(SAST::BVal,:$val);
        }
    } elsif $THIS.check.ostensible-type.enum-type {
        $THIS.check = $THIS.stage3-node(SAST::MethodCall, name => 'name', $THIS.check);
        self.walk($THIS.check);
    }
}

multi method walk(SAST::Accepts:D $THIS is rw) {
    my $thing   = $THIS[0];
    my $against =  $THIS[1];

    given $against {
        when .type ~~ tBool() { $THIS = $against }

        when *.ostensible-type.enum-type {
            $THIS .= stage2-node(SAST::EnumCmp,enum => $against,check => $thing);
            self.walk($THIS);
        }
        when SAST::Type {
            $THIS .= stage3-node(SAST::BVal,val => so($thing.ostensible-type ~~ $against.class-type));
        }
        when .type ~~ tRegex() {
            $THIS .= stage2-node(SAST::CmpRegex,:$thing,re => $against);
            self.walk($THIS);
        }
        when .type ~~ tStr()  {
            $THIS .= stage2-node(
                SAST::Cmp,
                sym => 'eq',
                $thing,
                $against,
            );
            self.walk($THIS);
        }
    }
}

multi method walk(SAST::Regex:D $THIS is rw) {
    with $THIS.src.compile-time {
        if Spit::P5Regex.parse($_,:actions(Spit::P5Regex-Actions)) -> $match {
            $THIS.patterns = $match.made.grep(*.value.defined).map: {
                .key => $THIS.stage3-node(SAST::SVal,val => .value)
            };
        } else {
            SX.new(message => "Spit regex parser wasn't able to parse ‘$_’" ~
                  "(Maybe you can just use '' quotes if you're sure it's right).",
                   match => $THIS.match).throw;
        }
    } else {
        $THIS.patterns<pre> = $THIS.src;
    }
}

multi method walk(SAST::CmpRegex:D $THIS is rw) {
    if $THIS.thing.compile-time -> $thing {
        my $p5regex := $THIS.re.compile-time;
        if $p5regex.defined {
            $THIS .= stage3-node(SAST::BVal,val => $thing.match($p5regex).so);
        }
    }
}

# The things we can inline in CondReturns is limited. We can't have
# any ol shell command expresssion. The ones we can inline depend
# on whether their last value as it appears in the shell is the same
# as their original. See 'ef' and 'et' for why.
sub acceptable-in-cond-return($_,$original) {
    when SAST::Cmd {
        (not .write || .append || .pipe-in || .in) and
        (.nodes[*-1] andthen .cloned === $original);
    }
    when SAST::MethodCall {
        (.pos[*-1] || .invocant) andthen .cloned === $original;
    }
    when SAST::Call {
        .pos[*-1] andthen .cloned === $original;
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
    if $THIS.declaration === tStr.^find-spit-method('Bool')
       and (my $ct = $THIS.invocant.compile-time).defined {
        $THIS .= stage3-node(SAST::BVal,val => ?$ct);
    }

    elsif $THIS.declaration === tEnumClass.^find-spit-method('name')
          and $THIS.invocant.compile-time -> $ct
    {
        $THIS .= stage3-node(SAST::SVal,val => $ct.name);
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
            # we'll need to re-walk to it has a chance to re-optimize itself.
            .stage3-done = False;
            self.walk($_);
            $_;
        }
    }
    when *.compile-time.defined {
        $*char-count += .compile-time.chars;
        $_;
    }
    default {
        Nil
    }
}

subset ChildSwapInline of SAST:D
       where SAST::Call|SAST::Cmd|SAST::Increment|SAST::Neg;

# CONSIDER:
#   {
#    sub foo($a) { say($a) }
#    foo "baz";
#   }
# 'foo("baz")' is the $outer call, 'say($a)' is the $inner call.
# We inline by switching the outer SAST::Call out for a modified clone of the inner SAST::Call.
# We can do this with a bun ch of other nodes as well.
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
            # Nodes without children are probably ok just to leave where they are but
            # give up if we have a node with children
            return
        }
    }
    $replacement;
}

multi method inline-call(SAST::Call:D $outer,SAST::CompileTimeVal:D $_) { $_ }

multi method inline-call(SAST::Call:D $outer,$) { Nil }

method add-scaffolding(SAST::Dependable:D $dep is rw)  {
    my $before = $dep;
    self.walk($dep);
    $!deps.add-scaffolding($dep, name => $before.?name);
    for $dep.all-deps {
        self.add-scaffolding($_);
    }
}

multi method include(SAST:D $sast) {
    return if $sast.included;
    $sast.included = True;

    if $sast ~~ SAST::Children and not $sast ~~ SAST::ClassDeclaration {
        for $sast.children {
            self.include($_);
        }
    }

    for |$sast.depends,|$sast.extra-depends <-> SAST::Dependable:D $dep {
        self.walk($dep);
        $dep.depended = True;
        if not $dep.included and not $dep.dont-depend {
            self.include($dep);
            $!deps.add-dependency($dep);
        }
    }
}

multi method include(SAST::PhaserBlock:D $phaser-block is rw) {
    self.include($phaser-block.block);
    $*CU.phasers[$phaser-block.stage].push($phaser-block.block);
    $phaser-block .= stage3-node(SAST::Empty,:included);
}
