use Spit::SAST;
need Spit::Exceptions;
need Spit::Constants;
need Spit::DependencyList;
use Spit::Metamodel;
need Spit::Sh::Method-Optimizer;
need Spit::Sh::Call-Inliner;
use Spit::Sastify;

unit class Spit::Sh::Composer does Method-Optimizer does Call-Inliner;


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
has $!log;
has $!NULL;
has $!ERR;
has $!OUT;
has %.clone-cache;
has $.no-inline;
has $.SETTING is required;

# Figures out what an option is assigned to at compile time
method compile-time-option($name) {
    my $declaration = $!SETTING.lookup(SCALAR,":$name");
    self.walk($declaration);
    if # if it has been tucked
       (my $match = $declaration.match and  $declaration ~~ SAST::Stmts)
       # or if its assignment is not compile time
       or ($match = $declaration.assign.match and $declaration.assign.compile-time === Nil) {
        # we can't use it as a definition for this option
        SX.new(message => "\$*$name definition too complex",:$match).throw;
    }
    $declaration.assign.compile-time;
}

method os {
    $!os ||= self.compile-time-option('os');
}

method log {
    $!log //= self.compile-time-option('log');
}

method NULL(:$match!) {
    $!NULL //= do {
        my $null = $!SETTING.lookup(SCALAR,':NULL').gen-reference(:stage2-done, :$match);
        self.walk($null);
        $null;
    };
}

method ERR(:$match!) {
    $!ERR //= do {
        my $err = $!SETTING.lookup(SCALAR,':ERR').gen-reference(:stage2-done, :$match);
        self.walk($err);
        $err;
    };
}


method OUT(:$match!) {
    $!OUT //= do {
        my $out = $!SETTING.lookup(SCALAR,':OUT').gen-reference(:stage2-done, :$match);
        self.walk($out);
        $out;
    };
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
    self.include($_) for $THIS.phasers.values.grep(*.defined).map(*.Slip);
    $THIS.depends-on = $!deps;
    $THIS.composed-for = $.os;
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

    # Check log outputs
    for $THIS.write -> $, $rhs is rw {
        if $rhs ~~ SAST::OutputToLog {
            my $cmd = $THIS.nodes[0];
            my $path = $rhs.path;

            if $THIS.logged-as -> $logged-as {
                if $path {
                    $path = $path.stage2-node(
                        SAST::Concat,
                        $logged-as,
                        $path.stage3-node(SAST::SVal, val => ':'),
                        $path
                    );
                    self.walk($path);
                } else {
                    $path = $logged-as;
                }
            }

            if !$path.defined {
                if $cmd ~~ SAST::Var {
                    $path = SAST::SVal.new(val => $cmd.bare-name, match => $rhs.match);
                }
                elsif $cmd.compile-time {
                    $path = $cmd;
                }
            }

            $rhs .= stage2-node(
                SAST::SubCall,
                name => 'log-fifo',
                declaration => $!SETTING.lookup(SUB,'log-fifo'),
                pos => (
                    $rhs.level,
                    ($path // Empty),
                ),
                match => $rhs.match
            );
            self.walk($rhs);
        }
    }

    if ($THIS.pipe-in andthen .is-self) -> $invocant {
        # vote to pipe the invocant
        $invocant.vote-pipe-yes;
    }
}

multi method walk(SAST::OutputToLog:D $THIS is rw) {
    if not $.log {
        $THIS = do given $THIS.level.compile-time {
            when * >= 2  { self.ERR(match => $THIS.match) }
            default      { self.NULL(match => $THIS.match) }
        }
    }
}

multi method walk(SAST::While:D $THIS is rw) {
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
                $THIS = reduce-block($else);
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

    self.walk($decl);

    # If the decl is a Stmts after walking it means it has been tucked
    # inside the block
    if $decl ~~ SAST::Stmts {
        $THIS.extra-depends.push($decl);
        # So we have to set it back to the right value, before going any further
        $decl .= last-stmt;
    }

    if $decl ~~ SAST::Option and $decl.required and not $decl.assign {
        SX::RequiredOption.new(name => $decl.bare-name, package => $decl.package, match => $THIS.match).throw;
    }

    if $decl ~~ SAST::ConstantDecl {
        if $decl.assign {
            with $decl.inline-value -> $inline {
                $THIS.switch: $inline;
            }
        } else {
            # If it has no assignment just inline to False
            $THIS.switch: SAST::BVal.new(match => $THIS.match, val => False);
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
        # $.pipe-vote > 0 means it will get piped.
        without $decl.pipe-vote {
            $decl.start-pipe-vote; # sets it to 1
        }
        # If the no vote here is balanced by a yes vote
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

method get-opt-value(Str:D $name, SAST::Block:D :$outer!, :$package) is raw {
    if ($package && %!opts{"{$package.name}:$name"}) or %!opts{$name} -> $val is copy {
        if $val ~~ Spit::LateParse {
            $ = ?(require Spit::Compile <&compile>);
            my $cu = compile(
                $val.val,
                :target<stage1>,
                :$outer,
                name => "opt:$name",
            );
            my $block = $cu.block;
            $val = $block;
        } else {
            $val .= deep-clone;
        }
        $val;
    } else {
        Nil
    }
}
multi method walk(SAST::Option:D $THIS is rw) {
    if self.get-opt-value($THIS.bare-name,
                          package => $THIS.package,
                          outer => $THIS.declared-in) -> $val is raw
    {
        my $*CURPAD = $THIS.declared-in;
        $val .= do-stage2($THIS.type);
        self.walk($val);
        $THIS.assign = $val;
    }
    callsame;
}

multi method walk(SAST::OptionVal:D $THIS is rw) {
    with $THIS.name.compile-time {
        if self.get-opt-value(.Str, outer => $THIS.pad) -> $val is raw
        {
            my $*CURPAD = $THIS.pad;
            $val .= do-stage2($THIS.ctx);
            self.walk($val);
            $THIS = $val;
        } else {
            $THIS .= stage3-node(SAST::Empty);
        }
    } else {
        SX.new(message => ‘Option's name must be known at compile time’,
               match => $THIS.match).throw;
    }
}

constant @placeholders = ("\c[
bouquet, revolving hearts,  blossom, two hearts, sunflower,growing heart,
rose, heart with arrow, cherry blossom, beating heart, tulip,
broken heart,  sparkling heart, hibiscus,blue heart, green heart, kiss mark,
yellow heart, purple heart, black heart, heart with ribbon,
heart decoration, wilted flower,love letter,rosette, white flower
]".comb xx ∞).flat.Array;


multi method walk(SAST::Eval:D $THIS is rw) {
    my %eval-opts = $THIS.opts;
    my @eval-args;
    for %eval-opts.kv -> $name, $opt is rw {
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
            );
            @eval-args.push($name);
        }
    }
    # let locally defined options override the outer definitions
    my %opts = |%.opts, |%eval-opts;

    $ = (require Spit::Compile <&compile>);
    my $compiled = $THIS.stage3-node(
        SAST::SVal,
        val => compile(
            name => "eval_{$++}",
            $THIS.src.val,
            opts => %opts,
            outer => $THIS.outer,
            :one-block,
        ),
        :!preserve-end
    );

    # Replace each runtime arg with a placeholder
    for @eval-args -> $name {
        my $rt-arg = %opts{$name};
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
        self.walk($_, accept => { acceptable-in-cond-return($_, $orig-invocant.identity) } );
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
    if $THIS.chosen-block -> $chosen {
        $THIS = $chosen;
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
                                        # RAKUDOBUG: I have to put :$accept here
multi method walk(SAST::MethodCall:D $THIS is rw, :$accept = True) {
    self.walk($THIS.declaration);
    # FIXME: method-optimize returns True if it FAILS (?!)
    self.method-optimize($THIS.declaration.class-type, $THIS, $THIS.declaration.identity)
      and callsame;
}

multi  method walk(SAST::Call:D $THIS is rw, :$accept = True) {
    my $decl := $THIS.declaration;
    self.walk($decl);

    # Add defaults to the call for missing args and then walk them
    self.walk($_) for $THIS.fill-in-defaults;

    return if $.no-inline;

    if $decl.chosen-block -> $block {
        if $block ~~ SAST::Block and not $block.ann<cant-inline> and not $decl.no-inline {
            # only inline routines with one child for now
            if $block.one-stmt <-> $last-stmt {
                # .inline-call is in Call-Inliner.pm6
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

        # should the method we're calling be piped to?
        if ($THIS.declaration.invocant andthen .piped) {
            # Is the call's invocant the $self of the method block we're in?
            if  ($THIS.invocant andthen .is-self) -> $self
            {
                # If so, vote for piping the method we're in's $self
                $self.vote-pipe-yes;
            }
            # Are any of the args to this piped method $self?
            elsif $THIS.deep-first(*.is-self) -> $self
            {
                # if so we *can't* pipe that $self
                $self.declaration.vote-pipe-no;
            }
        }
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
    $*CU.phasers[$phaser-block.stage].push($phaser-block.block);
    $phaser-block .= stage3-node(SAST::Empty,:included);
}

multi method include(SAST::Noisy:D $_) is default {
    .null = self.NULL(match => .match) if .silence-condition;
    callsame;
}
