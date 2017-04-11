use Spit::SAST;
use Spit::Metamodel;
need Spit::Constants;
need Spit::Exceptions;
need Spit::Sh::ShellElement;

my %native = (
    et => Map.new((
        body => Q<"$@" && eval "printf %s \"\$$#\"">,
        deps => (),
    )),
    ef => Map.new((
        body => Q<"$@" || { eval "printf %s \"\$$#\"" && return 1; }>,
        deps => (),
    )),
    list  => Map.new((
        body => q|printf "%s\n" "$*"|,
        deps => ('IFS'),
    )),
    starts-with => Map.new((
        body => Q<case "$1" in "$2"*) true;; *) false;; esac>,
        deps => ()
    )),
    ends-with => Map.new((
        body => Q<case "$1" in *"$2") true;; *) false;; esac>,
        deps => ()
    )),
);

sub nnq { NoNeedQuote.new: bits => @_ }
sub dq  { DoubleQuote.new: bits => @_ }
sub escape { Escaped.new: str => @_.join  }
sub cs { DoubleQuote.new: bits => ('$(',|@_,')')}
sub var { DoubleQuote::Var.new: name => $^a, :$:is-int }

sub lookup-method($class,$name) {
    $*SETTING.lookup(CLASS,$class).class.^find-spit-method($name);
}

my subset ShellStatus of SAST where {
    # 'or' and 'and' don't work here for some reason
    ($_ ~~ SAST::Neg|SAST::Cmp) ||
    ((.type ~~ tBool) && $_ ~~
      SAST::Stmts|SAST::Cmd|SAST::Call|SAST::If|SAST::Quietly|SAST::LastExitStatus
    )
}

unit class Spit::Sh::Compiler;


has Hash @!names;
has %.opts;
has $.chars-per-line-cap = 80;


method BUILDALL(|) {
    @!names[SCALAR]<_> = '_';
    for <shift chmod rm> {
        @!names[SUB]{$_} = $_;
    }
    callsame;
}

method scaffolding {
    my @a;
    for
    (SUB,'list'),
    (SCALAR,'IFS'),
    (SCALAR,'*NULL'),
    (SUB,'et'),
    (SUB,'ef'),
    (SUB,'e')
         {
        my $sast = $*SETTING.lookup(|$_) || die "scaffolding {$_.gist} doesn't exist";
        @a.push: $sast;
    }
    @a;
}

method require-native($name) {
     my %item := %native{$name};
     for |%native{$name}<deps> -> $name {
         self.scaf($name);
     }
     %item<body>;
}

method check-stage3($node) {
    SX::CompStageNotCompleted.new(stage => 3,:$node).throw  unless $node.stage3-done;
}

multi method gen-name(SAST::Declarable:D $decl,:$name is copy = $decl.name,:$fallback)  {
    self.check-stage3($decl);
    $name = do given $name {
        when '/' { 'M' }
        when '~' { 'B' }
        default { $_ }
    };

    do with $decl.ann<shell_name> {
        $_;
    } else {
        # haven't given this varible its shellname yet
        $_ = self!avoid-name-collision($decl,$name,:$fallback);
    }
}

multi method gen-name(SAST::PosParam:D $_) {
    return  ~(.ord + (.signature.has-invocant ?? 1 !! 0 ) + 1);
}

multi method gen-name(SAST::Invocant:D $) { '1' }

multi method gen-name(SAST::Var:D $_ where { $_ !~~ SAST::VarDecl }) {
    self.gen-name(.declaration);
}

multi method gen-name(SAST::MethodDeclare:D $method) {
    callwith($method,fallback => $method.invocant-type.name.substr(0,1).lc ~ '_' ~ $method.name);
}
method !avoid-name-collision($decl,$name is copy = $decl.name,:$fallback) {
    $name ~~ s/^['*'|'?']//;
    $name ~~ s:g/\W/_/;
    my $st = $decl.symbol-type;
    $st = SCALAR if $st == ARRAY;
    my $existing := @!names[$st]{$name};
    my $res = do given $existing {
        when :!defined { $name }
        when $fallback.defined { return self!avoid-name-collision($decl,$fallback) }
        when /'_'(\d+)$/ { $name ~ ('_' unless $name eq '_') ~ $/[0] + 1; }
        default { $name ~ ('_' unless $name eq '_') ~ '1' }
    }
    $existing = $res;
}

method scaf($name) {
    my $scaf = $*depends.require-scaffolding($name);
    $scaf.depended = True;
    self.gen-name($scaf);
}

# gets a late reference to variable that's in the scaffolding.
# At the time of commiting this is just needed for $*NULL.
method scaf-ref($name,:$match) {
    my $scaf = $*depends.require-scaffolding($name);
    if $scaf ~~ SAST::Stmts {
        $scaf .= last-stmt;
    }
    if $scaf.inline-value -> $inline {
        $inline;
    } else {
        $scaf.gen-reference(:stage3,:$match);
    }
}

method comp-depend($_){
    my ShellElement:D @comp = self.compile-nodes([$_],:indent).grep(*.defined);
    |do if @comp {
        Pair.new(key => $_,value => @comp)
    }
}

method compile(SAST::CompUnit:D $CU --> ShellElement:D) {
    my $*pad = '';
    my $*depends = $CU.depends-on;
    my ShellElement:D @compiled;

    my @MAIN = self.node($CU,:indent);

    my @END = ($CU.phasers[END] andthen self.compile-nodes($_,:indent));

    my @compiled-depends = $*depends.reverse-iterate( {  self.comp-depend($_) } );
    my @BEGIN = @compiled-depends && @compiled-depends.map({ ("\n" if $++),|.value}).flat;
    my @run;
    for :@BEGIN,:@MAIN {
        if .value {
            @compiled.append(.key,'()',|self.maybe-oneline-block(.value),"\n");
            @run.append(.key,' && ');
        }
    }

    @run.pop if @run; # remove last &&

    if @END {
        @compiled.append('END()',|self.maybe-oneline-block(@END),"\n","trap END EXIT\n",);
    }

    @compiled.append(|@run,"\n");
    @compiled.join("");
}

method maybe-oneline-block(@compiled) {
    if @compiled.first(/\n/) {
        "\{\n",|@compiled,"\n$*pad\}";
    } else {
        while @compiled and @compiled[0] ~~ /^\s*$/ {
            @compiled.shift;
        }
        '{ ', |@compiled,'; }';
    }
}

method compile-nodes(@sast,:$one-line,:$indent,:$no-empty) {
    my ShellElement:D @chunk;
    my $*indent = CALLERS::<$*indent> || 0;
    $*indent++ if $indent;
    my $*pad = '  ' x $*indent;
    my $sep = $one-line ?? '; ' !! "\n$*pad";
    my $i = 0;
    for @sast -> $node {
        my ShellElement:D @node = self.node( $node ).grep(*.defined);
        if @node {
            #if indenting, pad first statement
            @chunk.append: $i++ == 0 ??
                            ($*pad if $indent and not $one-line) !!
                            $sep;
            @chunk.append: @node;
        }
    }
    if $no-empty and not @chunk {
        @chunk.push("$*pad:");
    }
    return @chunk;
}

method space-then-arg(SAST:D $_) {
    if $_ !~~ SAST::Empty or .itemize {
        ' ', self.arg($_).itemize(.itemize)
    }
}

proto method node($node) {
    #note "node: {$node.^name}";
    self.check-stage3($node);
    {*};
}

proto method arg($node) {
    #note "arg: {$node.^name}";
    self.check-stage3($node);
    {*}.itemize(True)
}

proto method cond($node) {
    #note "cond: {$node.^name}";
    self.check-stage3($node);
    {*};
}

#!SAST
multi method node(SAST::CompUnit:D $*CU) {
    |self.node($*CU.block,|%_).grep(*.defined);
}

multi method node(SAST:D $_) { ': ',|self.arg($_) }

multi method arg(SAST:D $_) { cs(self.cap-stdout($_)) }

multi method cap-stdout(SAST:D $_) {
    self.scaf('e'),' ',|self.arg($_)
}

multi method loop-return(SAST:D $_) {
    self.scaf('list'),' ',|self.arg($_);
}

multi method cond(SAST:D $_) {
    if .type === tInt() {
        'test ',|self.arg($_), ' -ne 0';
    } else {
        'test ',|self.arg($_);
    }
}

multi method int-expr(SAST:D $_) { '$(',|self.cap-stdout($_),')' }

#!ShellStatus
multi method cond(ShellStatus:D $_) is default { self.node($_) }
multi method cap-stdout(ShellStatus $_) {
    |self.cond($_),' && ',self.scaf('e'),' 1';
}
#!Var
multi method node(SAST::Var:D $var) {
    my $name = self.gen-name($var);
    return Empty if $var ~~ SAST::ConstantDecl and not $var.depended;
    with $var.assign {
        my @var = |self.compile-assign($var,$_);
        if @var[0].starts-with('$') {
            @var.unshift(': ');
        }
        @var;
    } elsif $var ~~ SAST::VarDecl {
        $name,'=',($var.decl-type ~~ tInt() ?? '0' !! "''");
    } else {
        ': $',$name;
    }
}

multi method arg(SAST::Var:D $var) {
    my $name = self.gen-name($var);
    my $assign = $var.assign;
    with $assign {
        if $assign ~~ SAST::Junction:D and $assign.dis {
            dq self.compile-assign($var,$assign);
        } else {
            SX::NYI.new(feature => 'Non declaration assignment as an argument',node => $var).throw
        }
    } else {
        var $name, is-int => ($var.type ~~ tInt());
    }
}

multi method compile-assign($var,SAST:D $_) { self.gen-name($var),'=',|self.arg($_) }
multi method compile-assign($var,SAST::Junction:D $j) {
    # is this a $a ||= "foo" ?
    my $or-equals = do given $j[0] {
        $_ ~~ SAST::CondReturn
        and .when == True # ie || not &&
        and $var.uses-Str-Bool # they Boolify using Str.Bool
        and .val.?declaration === $var.declaration # var refers to same thing
    }
    if $or-equals and $var.type ~~ tStr() {
        my $name = self.gen-name($var);
        '${',$name,':=', |self.arg($j[1]).in-or-equals,'}';
    } else {
        nextsame;
    }
}

multi method compile-assign($var,SAST::Call:D $call) {
    if $call.declaration.impure {
        |self.node($call),'; ',self.gen-name($var),'=$R';
    } else {
        nextsame;
    }
}

multi method int-expr(SAST::Var:D $_) {
    my $name = self.gen-name(.declaration);
    if $name.Int {
        '$',$name;
    } else {
        $name;
    }
}
#!If
multi method node(SAST::If:D $_,:$else) {
    self.try-case($_) andthen .return;

    substitute-cond-topic(.topic-var,.cond);

    ($else ?? 'elif' !! 'if'),' ',
    |(|self.node(.topic-var),'; ' if .topic-var andthen .depended),
    |self.cond(.cond),"; then\n",
    |self.node(.then,:indent,:no-empty),
    |(with .else {
         when SAST::Empty   { Empty }
         when SAST::If    { "\n{$*pad}",|self.node($_,:else) }
         when SAST::Stmts { "\n{$*pad}else\n",|self.node($_,:indent,:no-empty) }
     } elsif .type ~~ tBool() {
          # if false; then false; fi; actually exits 0 (?!)
          # So we have to make sure it exits 1 if the cond is false
          "\n{$*pad}else\n{$*pad}  false"
     }),
    ( "\n{$*pad}fi" unless $else );
}

# turns stuff like:
# if test "$(cat $file)"; do ...
# into:
# if _1="$(cat $file)"; if test "$_1"; do ...
sub substitute-cond-topic($topic-var,$cond is rw) {
    if $topic-var andthen .depended {
        my $target := $topic-var.assign;
        $cond.descend: {
            if $_ === $target {
                $_ = $topic-var.gen-reference(
                    match => $cond.match,
                    :stage3-done,
                );
            }
        }
    }
}

method try-case($if is copy) {
    my $can = True;
    my $common-topic;
    my @res;
    my $i = 0;
    while $if and $can {
        my ($topic,$pattern);
        if $if !~~ SAST::If {
            @res.append: "\n$*pad  *) ", |self.node($if,:one-line),';;';
            $if = Nil;
        } elsif (
            (my \cond = $if.cond) ~~ SAST::Cmp && cond.sym eq 'eq'
                && ($topic = cond[0]; $pattern := |self.arg(cond[1]))
            or
            cond ~~ SAST::MethodCall && cond.declaration.cloned === (once lookup-method 'Str','match')
                && (my $re := cond.pos[0]) ~~ SAST::Regex && (my $case = $re.patterns<case>)
                && ($topic = cond[0]; $pattern := $case.val)
            or
            cond ~~ SAST::MethodCall && cond.declaration.cloned === (once lookup-method 'EnumClass','has-member')
                && (my $enum := cond[0].compile-time) ~~ Spit::Type
                && ($topic = cond.pos[0]; $pattern := $enum.^types-in-enum».name.join('|'))
            )
          {
              $common-topic //= $topic;
              if (given $common-topic {
                 when SAST::CompileTimeVal { $topic.val ===  .val }
                 when SAST::Var { $topic.declaration === .declaration }
                 when SAST::MethodCall {
                     # DIRTY HACK: I want to make 'given SomeEnum { when ..}' caseable.
                     # But each cond will be wrapped in a call to .name to remove '|' from it.
                     # TODO: A general solution to to case method calls
                     $topic.declaration === .declaration
                     && .declaration === (once lookup-method('EnumClass','name')),
                 }
              }) {
                  @res.append: "\n$*pad  ",$pattern,') ', |self.node($if.then,:one-line),";;";
                  $i++;
              } else {
                  $can = Nil;
              }
              $if = $if.else;
          } else {
            $can = Nil;
        }
    }
    $can = Nil if $i < 2;
    if $can {
        @res.prepend: 'case ', |self.arg($common-topic), ' in ';
        @res.append: "\n{$*pad}esac";
    }
    $can && @res;
}

multi method cap-stdout(SAST::If:D $_) {
    nextsame when ShellStatus;
    self.node($_);
}
#!While
multi method node(SAST::While:D $_) {
    substitute-cond-topic(.topic-var,.cond);

    .until ?? 'until' !! 'while',' ',
    |(|self.node(.topic-var),'; ' if .topic-var andthen .depended),
    |self.cond(.cond),"; do \n",
    |self.node(.block,:indent,:no-empty),
    "\n{$*pad}done";
}
multi method cap-stdout(SAST::While:D $_) { self.node($_) }
#!Given
multi method node(SAST::Given:D $_) {
    |(|self.node(.topic-var),'; ' if .topic-var.depended),
    |self.node(.block,:curlies)
}

multi method cond(SAST::Given:D $_) { self.node($_) }

multi method arg(SAST::Given:D $_) { cs self.node($_) }
#!For
multi method node(SAST::For:D $_) {
    self.scaf('IFS');
    'for ', self.gen-name(.iter-var), ' in', |.list.children.map({ self.space-then-arg($_) }).flat
    ,"; do\n",
    |self.node(.block,:indent,:no-empty),
    "\n{$*pad}done"
}
multi method cap-stdout(SAST::For:D $_) { self.node($_) }
#!Junction
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
        |self.arg(RHS),
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
        '{ ',self.cond(.val), ' && ',self.scaf('e'), ' 1;',' }';
    } elsif .when === False and .val.uses-Str-Bool or !.Bool-call {
        # Special case shell optimization!!!
        # $(test "$foo" || { echo "$foo" && false; }  && echo "$bar")
        # can be reduced-to: (test "$foo" || echo "$bar")
        self.cond(.val);
    } else {
        self.scaf(.when ?? 'et' !! 'ef'),' ',|self.cond(.Bool-call);
    }
}

multi method cond(SAST::CondReturn:D $_,|c) { self.cond(.val,|c) }
#!Ternary
multi method node(SAST::Ternary:D $_,:$tight) {
    # shouldn't this also be checking for Boo
    ('{ ' if $tight),
    |self.cond(.cond),' && ',|self.compile-in-ctx(.on-true,:tight),' || ',|self.compile-in-ctx(.on-false,:tight),
    ('; }' if $tight);
}

multi method cap-stdout(SAST::Ternary:D $_,:$tight) {
    self.node($_,:$tight);
}

multi method cond(SAST::Ternary:D $_,|c)  {
    self.node($_,|c);
}
#!Block
#!Stmts
multi method node(SAST::Stmts:D $block,:$indent is copy,:$curlies,:$one-line,:$no-empty) {
    $indent ||= True if $curlies;
    my @compiled = self.compile-nodes($block.children,:$indent,:$one-line,:$no-empty);
    if $curlies {
        self.maybe-oneline-block(@compiled);
    } else {
        |@compiled;
    }
}

multi method arg(SAST::Stmts:D $_) {
    cs self.node($_,:one-line);
}

#!LastExitStatus
multi method cond(SAST::LastExitStatus:D $_) {
    'expr $? = 0 >', '&',self.arg(self.scaf-ref('*NULL',match => .match));
}

multi method arg(SAST::LastExitStatus:D $_) { '$?' }

multi method node(SAST:D $_ where SAST::Increment|SAST::IntExpr) { ': ',|self.arg($_,:sink) }
#!Increment
multi method arg(SAST::IntExpr:D $_) { nnq '$((', |self.int-expr($_),'))' }
#!IntExpr
multi method arg(SAST::Increment:D $_,:$sink) {
    nnq do if .[0] ~~ SAST::Var {
        my $decl = .[0].declaration;
        my @inc = self.gen-name($decl),(.decrement ?? '-' !! '+'),'=1';
        if .pre or $sink {
            '$((',|@inc,'))';
        } else {
            '$(((',|@inc,')',(.decrement ?? '+' !! '-'),'1))';
        }
    } else {
        die "tried to increment something that isn't a variable";
    }
}
multi method int-expr(SAST::IntExpr:D $_,:$tight) {
    ('(' if $tight),|self.int-expr(.[0]),.sym,|self.int-expr(.[1],:tight),(')' if $tight);
}
#!Negative
multi method arg(SAST::Negative:D $_) { self.arg(.as-string) }
multi method int-expr(SAST::Negative:D $_) {
    '-',|self.int-expr($_[0],:tight);
}
#!RoutineDeclare
multi method node(SAST::RoutineDeclare:D $_) {
    return if not .depended or .ann<compiled-already>;
    # because subs can be post-declared, weirdness can happen where
    # they get compiled twice, once in BEGIN and once in MAIN. We have
    # to keep track of them. TODO just get rid of subs declarations
    # in MAIN altogether?
    .ann<compiled-already> = True;
    my $name = self.gen-name($_);
    my @compiled = do if .is-native {
        self.require-native(.name);
    } else {
        self.node(.chosen-block,:indent,:no-empty);
    }
    $name,'()',|self.maybe-oneline-block(@compiled)
}

method call($name,@named-param-pairs,@pos) {
    |@named-param-pairs.\ # Errr rakudo, why do I need \ here?
       grep({.value.compile-time !=== False }).\
       map({ self.gen-name(.key),"=",|self.arg(.value),' '} ).flat,
    $name,
    |@pos.map({ ' ',|self.arg($_) }).flat;
}
#!Call
multi method node(SAST::SubCall:D $_)  {
    self.call(self.gen-name(.declaration),.param-arg-pairs,.pos);
}

multi method node(SAST::MethodCall:D $_) {
    my $call := |self.call: self.gen-name(.declaration),
                .param-arg-pairs,
                (( .declaration.static ?? Empty !! .invocant),|.pos);
    if .declaration.rw and .invocant.assignable {
        |self.gen-name(.invocant),'=$(',$call,')';
    } else {
        $call;
    }
}

multi method arg(SAST::Call:D $_) is default {
    SX::Sh::ImpureCallAsArg.new(call-name => .name,node => $_).throw if .declaration.impure;
    nextsame;
}

multi method cap-stdout(SAST::Call:D $_) is default {
    nextsame when ShellStatus;
    self.node($_)
}
#!Cmd
multi method node(SAST::Cmd:D $cmd,:$silence) {

    if $cmd.nodes == 0 {
        my @cmd-body = self.cap-stdout($cmd.pipe-in);
        self.compile-cmd(@cmd-body,$cmd.write,$cmd.append,());
    } else {
        my @in = $cmd.in;
        my @cmd-body  = |$cmd.nodes.map({ $++
                                          ?? self.space-then-arg($_)
                                          !! self.arg($_).itemize(.itemize) }
                                       ).flat;

        my $full-cmd := |self.compile-cmd(@cmd-body,$cmd.write,$cmd.append,@in);
        my $pipe     := |(|self.cap-stdout($_),'|' with $cmd.pipe-in);
        |$pipe,
        ("\n{$*pad}" if $pipe and $pipe.chars + $full-cmd.chars > $.chars-per-line-cap),
        |$cmd.set-env.map({"{.key.subst('-','_',:g)}=",|self.arg(.value)," "}).flat,
        |$full-cmd;
    }
}

method compile-cmd(@cmd-body,@out-write,@out-append,@in) {
    my @redir;
    my $eval;

    my @redirs := 1,'>' ,@out-write,
                  1,'>>',@out-append,
                  0,«<» ,@in;

    for @redirs -> $default-lhs, $sym, @list {
        for @list -> $lhs,$rhs {
            my $lhs-ct := $lhs.compile-time;
            $eval = True without $lhs-ct;
            @redir.push: list ($lhs-ct ~~ $default-lhs ?? '' !! self.arg($lhs));
            @redir.push($sym);
            @redir.push: list ('&' if $rhs.type ~~ tFD()),
                              ($rhs.compile-time ~~ -1 ?? '-' !! |self.arg($rhs));
        }
    }
    if $eval {
        'eval ',escape(|@cmd-body," "),
        |@redir.map(-> $in,$sym,$out { |$in,escape($sym, $out.flat) }).flat;
    } else {
        |@cmd-body,|(@redir.map(-> $a,$b,$c {' ',|$a,|$b,|$c}).flat if @redir) ;
    }
}


multi method cap-stdout(SAST::Cmd:D $_) {
    nextsame when ShellStatus;
    self.node($_);
}

#!Return
multi method node(SAST::Return:D $ret) {
    if $ret.impure {
        'R=',self.arg($ret.val);
    } elsif $ret.loop {
        self.loop-return($ret.val);
    } else {
        # If we're returning the exit status of the last cmd we can just do nothing
        # because that's what will be retuned if we do.
        if $ret.val ~~ SAST::LastExitStatus and $ret.ctx ~~ tBool() {
            Empty;
        }
        elsif $ret.val.compile-time ~~ '' {
            Empty;
        }
        else {
            self.compile-in-ctx($ret.val,|%_);
        }
    }
}

method compile-in-ctx($node,*%_) {
    given $node.ctx {
        when tBool() { self.cond($node,|%_)       }
        when tStr()  { self.cap-stdout($node,|%_) }
        when tAny()  { self.node($node,|%_) }
        default {
            SX::Bug.new(:$node,desc => "{$node.^name}'s type context {.gist} is invalid").throw
        }
    }
}
#!Empty
multi method node(SAST::Empty:D $_) { Empty }
multi method  arg(SAST::Empty:D $_) { dq '' }

#!Quietly
multi method node(SAST::Quietly:D $_) {
    |self.node(.block,:curlies),' 2>',('&' if .null.type ~~ tFD()),self.arg(.null);
}

#!Neg
multi method cond(SAST::Neg:D $_) { '! ',|self.cond(.children[0],:tight) }

#!Cmp
multi method cond(SAST::Cmp:D $cmp) {
    my $shell-sym = do given $cmp.sym {
        when '==' { '-eq' }
        when 'eq' {  '=' }
        when '!=' { '-ne' }
        when '<'  { '-lt' }
        when '>'  { '-gt' }
        when '<=' { '-le' }
        when '>=' { '-ge' }
        when 'ne' {  '!=' }
        when 'lt' {  '<'  }
        when 'gt' {  '>'  }
        when 'le' {  '<=' }
        when 'ge' {  '>=' }
        default { "'$_' comparison NYI" }
    }

    '[ ',|self.arg($cmp[0])," $shell-sym ",|self.arg($cmp[1]),' ]';
}

#!BVal
multi method arg (SAST::BVal:D $_) { .val ?? '1' !! '""' }
multi method cond(SAST::BVal:D $_) { .val ?? 'true' !! 'false' }
multi method int-expr(SAST::BVal $ where { .val === False } ) { '0' }
#!SVal
multi method arg(SAST::SVal:D $_) { escape .val }
#!IVal
multi method arg(SAST::IVal:D $_) { .val.Str }
multi method int-expr(SAST::IVal:D $_) { .val.Str }
#!Eval
multi method arg(SAST::Eval:D $_) { self.arg(.compiled) }
#!Regex
multi method arg(SAST::Regex:D $_) { self.arg(.src) }
multi method cap-stdout(SAST::Regex:D $_) { self.cap-stdout(.pre) }
#!Range
multi method arg(SAST::Range:D $_) {
    cs 'seq ',
    |(.exclude-start
      ?? ('$((',|self.int-expr($_[0]),'+1))')
      !! |self.arg($_[0])
     )
    ,' ',
    |(.exclude-end
      ?? ('$((',|self.int-expr($_[1]),'-1))')
      !! |self.arg($_[1])
     )
}
#!Blessed
multi method arg(SAST::Blessed:D $_) { self.arg($_[0]) }

#!Concat
multi method arg(SAST::Concat:D $_) {
    return '""' unless .children;
    my @compiled = .children.flatmap({ self.arg($_) });
    my $str = dq();

    my $last-var;
    for @compiled.reverse.kv -> $i,$_ {
        $str.bits.prepend(.in-DQ(next => $str.bits.head));
    }
    $str;
}
#!Type
multi method arg(SAST::Type $_) {
    if .class-type.enum-type {
        escape .class-type.^types-in-enum».name.join('|')
    } else {
        escape .gist
    }
}
#!Itemize
multi method arg(SAST::Itemize:D $_) { self.arg($_[0]) }
multi method cap-stdout(SAST::Itemize:D $_) { self.cap-stdout($_[0]) }
#!List
multi method cap-stdout(SAST::List:D $_) {
    if .children > 1 {
        self.scaf('list'),|.children.map({ ' ', |self.arg($_) }).flat;
    } else {
        self.cap-stdout(.children[0]);
    }
}

multi method loop-return(SAST::List:D $_) {
    if .children > 1 {
        self.cap-stdout($_);
    } else {
        self.loop-return(.children[0]);
    }
}
#!Doom
# If we try and compile Doom we're doomed
multi method arg(SAST::Doom:D $_)  { .exception.throw }

multi method arg(SAST::NAME:D $_) {
    if try self.gen-name($_[0]) -> $name {
        escape $name;
    } else {
        SX.new(message => ‘value doesn't have name’, node => $_[0]).throw;

    }
}
