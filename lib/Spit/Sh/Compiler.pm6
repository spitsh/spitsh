use Spit::SAST;
use Spit::Metamodel;
need Spit::Constants;
need Spit::Exceptions;

sub shell_quote(Str() $str is copy){
    if $str !~~
    /^[
        |\w
        |<[-!%+,./:[\]=@]>
    ]+$/ {
        return '\\' ~ $str if $str.chars == 1 and not $str ~~ "\n";
        # lol wut
        if $str ~~ /<["$]>/ or $str ~~ /'\\'$/ {
            $str .= subst("'","'\\''",:g);
            $str = "'$str'";
        } else {
            $str = '"' ~ $str ~ '"';
        }
        $str .= subst(/^"''"/,'');
        $str .= subst(/"''"$/,'');
    }
    return $str;
}

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
        body => q|printf %s "$*"|,
        deps => ('IFS'),
    )),
    starts-with => Map.new((
        body => q|case "$1" in "$2"*) true;; *) false;; esac|,
        deps => ()
    )),
    ends-with => Map.new((
        body => q|case "$1" in *"$2") true;; *) false;; esac|,
        deps => ()
    )),
);


sub lookup-method($class,$name) {
    $*SETTING.lookup(CLASS,$class).class.^find-spit-method($name);
}

my subset ShellStatus of SAST where {
    # 'or' and 'and' don't work here for some reason
    ($_ ~~ SAST::Neg|SAST::Cmp|SAST::EnumCmp|SAST::CmpRegex) ||
    ((.type ~~ tBool) && $_ ~~
      SAST::Block|SAST::Cmd|SAST::Call|SAST::If|SAST::Quietly
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
    (SUB,'re-match'),
    (SUB,'pre-match'),
    (SUB,'e')
         {
        my $sast = $*SETTING.lookup(|$_) || die "scaffolding {$_.gist} doesn't exist";
        @a.push: $sast;
    }
    @a.push(lookup-method('EnumClass','has-member'));
    @a;
}

method require-native($name) {
     my %item := %native{$name};
     for |%native{$name}<deps> -> $name {
         self.scaf($name);
     }
     %item<body>;
}

method quote(*@strings,:$flat) {
    self.scaf('IFS') if $flat;
    ('"' unless $flat),|@strings,('"' unless $flat);
}

method check-stage3($node) {
    SX::CompStageNotCompleted.new(stage => 3,:$node).throw  unless $node.stage3-done;
}

multi method gen-name(SAST::Declarable:D $decl,:$name is copy = $decl.name,:$fallback) returns Str:D {
    self.check-stage3($decl);

    do with $decl.ann<shell_name> {
        $_;
    } else {
        # haven't given this varible its shellname yet
        $_ = self!avoid-name-collision($decl,:$fallback);
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
    $name ~~ s:g/'-'/_/;
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

method comp-depend($_){
    my Str:D @comp = self.compile-nodes([$_],:indent).grep(*.defined);
    |do if @comp {
        Pair.new(key => $_,value => @comp)
    }
}

method compile(SAST::CompUnit:D $CU --> Str:D) {
    my $*pad = '';
    my $*depends = $CU.depends-on;
    my Str:D @compiled;

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

proto method node($node) {
    #note "node: {$node.^name}";
    self.check-stage3($node);
    {*};
}

proto method arg($node) {
    #note "arg: {$node.^name}";
    self.check-stage3($node);
    {*};
}

proto method cond($node) {
    #note "cond: {$node.^name}";
    self.check-stage3($node);
    {*};
}

multi method node(SAST::CompUnit:D $*CU) {
    |self.node($*CU.block,|%_).grep(*.defined);
}

method compile-nodes(@sast,:$one-line,:$indent) {
    my Str:D @chunk;
    my $*indent = CALLERS::<$*indent> || 0;
    $*indent++ if $indent;
    my $*pad = '  ' x $*indent;
    my $sep = $one-line ?? '; ' !! "\n$*pad";
    my $i = 0;
    for @sast -> $node {
        my Str:D @node = self.node( $node ).grep(*.defined);
        if @node {
            #if indenting, pad first statement
            @chunk.append: $i++ == 0 ??
                            ($*pad if $indent and not $one-line) !!
                            $sep;
            @chunk.append: @node;
        }
    }
    # unless @chunk {
    #     @chunk.append: $*pad,': nop';
    # }
    return @chunk;
}

multi method node(SAST::Param:D $p) { Empty }

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
        $name,'=',($var.decl-type ~~ tInt() ?? '0' !! '""');
    } else {
        ': $',$name;
    }
}

multi method node(SAST::Coerce:D $node) {
    self.node($node[0]);
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
        '${',$name,':=',|self.arg($j[1]),'}';
    } else {
        nextsame;
    }
}

multi method compile-assign($var,SAST::Call:D $call) {
    if $call.declaration.impure {
        |self.node($call),'; ',self.gen-name($var),'="$R"';
    } else {
        nextsame;
    }
}

method try-case($if is copy) {
    my $can = True;
    my $common-topic;
    my @res;
    my $i = 0;
    while $if and $can {
        my ($topic,$pattern);
        if $if ~~ SAST::Block {
            @res.append: "\n$*pad  *) ", |self.node($if,:inline,:one-line),';;';
            $if = Nil;
        } elsif (
            $if.cond ~~ SAST::Cmp && $if.cond.sym eq 'eq'
                && ($topic = $if.cond[0]; $pattern := |self.arg($if.cond[1]))
            or
            $if.cond ~~ SAST::CmpRegex && (my $case := $if.cond.re.patterns<case>)
                && ($topic = $if.cond.thing; $pattern := $case.val)
            )
            or
            $if.cond ~~ SAST::EnumCmp && ($if.cond.enum ~~ SAST::Type)
                && ($topic = $if.cond.check; $pattern := |self.arg($if.cond.enum,:flat))
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

multi method node(SAST::If:D $_,:$else) {
    self.try-case($_) andthen .return;

    substitute-cond-topic(.topic-var,.cond);

    ($else ?? 'elif' !! 'if'),' ',
    |(|self.node(.topic-var),'; ' if .topic-var andthen .depended),
    |self.cond(.cond),"; then\n",
    |self.node(.then,:indent,:no-empty),
    |(with .else {
         when SAST::Nop   { Empty }
         when SAST::Block { "\n{$*pad}else\n",|self.node($_,:indent) }
         default { "\n{$*pad}",|self.node($_,:else) }
     } elsif .type ~~ tBool() {
          # if false; then false; fi; actually exits 0 (?!)
          # So we have to make sure it exits 1 if the cond is false
          "\n{$*pad}else\n{$*pad}  false"
     }),
    ( "\n{$*pad}fi" unless $else );
}

multi method node(SAST::While:D $_) {
    substitute-cond-topic(.topic-var,.cond);

    .until ?? 'until' !! 'while',' ',
    |(|self.node(.topic-var),'; ' if .topic-var andthen .depended),
    |self.cond(.cond),"; do \n",
    |self.node(.block,:indent),
    "\n{$*pad}done";
}

multi method node(SAST::Given:D $_) {
    |(|self.node(.topic-var),'; ' if .topic-var.depended),
    |self.node(.block,:curlies)
}

multi method node(SAST::For:D $_) {
    self.scaf('IFS');
    my @list = .list.children;
    my $flat = @list == 1 && @list[0].type ~~ tList();
    'for ', self.gen-name(.iter-var), ' in', |.list.children.flatmap({ ' ',self.arg($_,:$flat) })
    ,"; do\n",
    |self.node(.block,:indent),
    "\n{$*pad}done"
}


multi method node(SAST::Junction:D $_) {
    |self.cond($_[0]), (.dis ?? ' || ' !! ' && '),|self.node($_[1])
}

multi method node(SAST::Ternary:D $_,:$tight) {
    # shouldn't this also be checking for Boo
    ('{ ' if $tight),
    |self.cond(.cond),' && ',|self.compile-in-ctx(.on-true,:tight),' || ',|self.compile-in-ctx(.on-false,:tight),
    ('; }' if $tight);
}

multi method node(SAST::Block:D $block,:$indent is copy,:$curlies,:$one-line) {
    $indent ||= True if $curlies;
    my @compiled = self.compile-nodes($block.children,:$indent,:$one-line);
    if $curlies {
        self.maybe-oneline-block(@compiled);
    } else {
        |@compiled;
    }
}

multi method node(SAST:D $_ where SAST::Increment|SAST::IntExpr) { ': ',|self.arg($_,:sink) }

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

multi method node(SAST::RoutineDeclare:D $_) {
    return if not .depended or .ann<compiled-already>;
    # because subs can be post-declared, weirdness can happen where
    # they get compiled twice, once in BEGIN and once in MAIN we have
    # to keeep track of them. TODO just get rid of subs declarations
    # in MAIN alltogether?
    .ann<compiled-already> = True;
    my $name = self.gen-name($_);
    my $*LATE-INIT = {};
    my @compiled = do if .is-native {
        self.require-native(.name);
    } else {
        self.node(.chosen-block,:indent,:no-empty);
    }
    if $*LATE-INIT {
        @compiled.prepend: "  $*pad",$*LATE-INIT.keys.map({ "$_=\"\"" }).join(" "),"\n";
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

multi method node(SAST::SubCall:D $_)  {
    self.call(self.gen-name(.declaration),.param-arg-pairs,.pos);
}

multi method node(SAST::MethodCall:D $_) {
    my $call := |self.call: self.gen-name(.declaration),
                .param-arg-pairs,
                (( .declaration.static ?? Empty !! .invocant),|.pos);
    if .declaration.rw and .invocant.assignable {
        |self.gen-name(.invocant),'=',|self.quote('$(',$call,')');
    } else {
        $call;
    }
}

method compile-cmd(@cmd-body,@write,@append,:$stdin) {
    my @redir;
    my $eval;
    for '>', @write,'>>',@append -> $sym,@list {
        for @list -> $in,$out {
            my $in-ct := $in.compile-time;
            $eval = True unless $in-ct;
            @redir.push: list ($in-ct ~~ 1 ?? '' !! self.arg($in));
            @redir.push($sym);
            @redir.push: list ('&' if $out.type ~~ tFD()),($out.compile-time ~~ -1 ?? '-' !! |self.arg($out));
        }
    }
    if $stdin {
        @redir.append: '',q{<}; #>;
        @redir.push: list ('&' if $stdin.type ~~ tFD()),self.arg($stdin);
    }
    if $eval {
        'eval ',|shell_quote((|@cmd-body," ").join),
        |@redir.map(-> $in ,$sym,$out { |$in,|shell_quote($sym ~ $out.flat.join) }).flat;
    } else {
        |@cmd-body,|(@redir.map(-> $a,$b,$c {' ',|$a,|$b,|$c}).flat if @redir) ;
    }
}

multi method node(SAST::Cmd:D $cmd,:$silence) {
    my ($stdin,$pipe-in);

    if $cmd.in ~~ SAST::FileContent {
        $stdin = $cmd.in.file;
    } elsif $cmd.in.defined {
        $pipe-in = $cmd.in;
    }

    my @cmd-body = |(self.arg($cmd.cmd),|$cmd.nodes.map({(' ',self.arg($_)) })).flat;
    my $full-cmd := |self.compile-cmd(@cmd-body,$cmd.write,$cmd.append,:$stdin);
    my $pipe := |(|self.cap-stdout($_),'|' with $pipe-in);
    |$pipe,
    ("\n{$*pad}" if $pipe and $pipe.chars + $full-cmd.chars > $.chars-per-line-cap),
    |$cmd.set-env.map({"{.key.subst('-','_',:g)}=",|self.arg(.value)," "}).flat,
    |$full-cmd;
}

multi method node(SAST::WriteToFile:D $wtf) {
    self.compile-cmd(self.cap-stdout($wtf.in),$wtf.write,$wtf.append);
}

multi method node(SAST::Return:D $ret) {
    if $ret.impure {
        'R=',self.arg($ret.val);
    } else {
        self.compile-in-ctx($ret.val,|%_);
    }
}

method compile-in-ctx($node,*%_) {
    given $node.ctx {
        when tBool() { self.cond($node,|%_)       }
        when tStr()  { self.cap-stdout($node,|%_) }
        when tAny()  { self.node($node,|%_) }
        default {
            SX::Bug.new(:$node,desc => "Node's type context {.gist} is invalid").throw
        }
    }
}

multi method node(SAST:D $_) {
    ': ',|self.arg($_);
}

multi method node(SAST::Nop:D $_,:$indent,:$no-empty) {
    if $no-empty {
        $*pad,'  :nop';
    } else {
        Empty
    }
}

multi method node(SAST::Quietly:D $_) {
    |self.node(.block,:curlies),' 2>',('&' if .null.type ~~ tFD()),self.arg(.null);
}

multi method cond(SAST:D $_) {
    if .type === tInt() {
        'test ',|self.arg($_), ' -ne 0';
    } else {
        'test ',|self.arg($_);
    }
}

multi method cond(SAST::Neg:D $_) {
    '! ',|self.cond(.children[0],:tight);
}

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

multi method cond(SAST::EnumCmp:D $cmp) {
    my $check := do if $cmp.check ~~ SAST::Type {
        shell_quote($cmp.check.class-type.^name);
    }  else {
        |self.arg($cmp.check);
    }
    self.scaf('has-member'),' ',|self.arg($cmp.enum),' ',|$check;
}

multi method cond(SAST::Junction:D $_,:$tight) {
    ('{ ' if $tight ),
    |self.cond($_[0]), (.dis ?? ' || ' !! ' && '),|self.cond($_[1],:tight),
    ('; }' if $tight );
}
multi method cond(SAST::CondReturn:D $_,|c) {
    self.cond(.val,|c);
}

multi method cond(SAST::CmpRegex:D $_) {
    if .re ~~ SAST::Regex {
        if .re.patterns<ere> -> $ere  {
            self.scaf('re-match'),' ',|self.arg(.thing),' ',|self.arg($ere);
        } else {
            self.scaf('pre-match'),' ',|self.arg(.thing),' ',|self.arg(.re.patterns<pre>);
        }
    } else {
        self.scaf('pre-match'),' ',|self.arg(.thing),' ',|self.arg(.re);
    }
}

multi method cond(ShellStatus:D $_) is default {
    self.node($_);
}

multi method cond(SAST::BVal:D $_) {
    .val ?? 'true' !! 'false';
}

multi method arg(SAST::SVal:D $_) { .val.&shell_quote }
multi method arg(SAST::IVal:D $_) { .val.Str }
multi method arg(SAST::BVal:D $_) { .val ?? '1' !! '""' }

multi method arg(SAST::Eval:D $_) { self.arg(.compiled) }
multi method arg(SAST::Var:D $var,:$flat) {
    my $name = self.gen-name($var);
    my $assign = $var.assign;
    my @var = do with $assign {
        if $assign ~~ SAST::Junction:D and $assign.dis {
            self.compile-assign($var,$assign);
        } elsif $var ~~ SAST::VarDecl {
            $*LATE-INIT{$name} = True if $*LATE-INIT.defined;
            '${',$name,':=',|self.arg($assign),'}';
        } else {
            SX::NYI.new(feature => 'Non declaration assignment as an argument',node => $var).throw
        }
    } else {
        '$',$name;
    }

    if $var.type ~~ tInt() {
        |@var;
    } else {
        self.quote: |@var,:$flat;
    }
}

multi method arg(SAST::Regex:D $_) {
    self.arg(.src);
}

multi method arg(SAST::IntExpr:D $_) { '$((', |self.int-expr($_),'))' }
multi method arg(SAST::Increment:D $_,:$sink) {
    do if .[0] ~~ SAST::Var {
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
multi method arg(SAST::Range:D $_,:$flat) {
    self.quote: '$(seq ',
    |(.exclude-start
     ?? ('$((',|self.int-expr($_[0]),'+1))')
     !! |self.arg($_[0])
    )
    ,' ',
    |(.exclude-end
      ?? ('$((',|self.int-expr($_[1]),'-1))')
      !! |self.arg($_[1])
    ),
    ')',:$flat;
}

multi method arg(SAST::Blessed:D $_) {
    with $_[0] {
        self.arg($_);
    }
}

multi method arg(SAST::Elem:D $_) { die 'SAST::Elem made it to compiler' }

multi method arg(SAST::FileContent:D $_,:$flat) {
    self.quote: :$flat,
    '$(cat ',('<&' if .file.type ~~ tFD),|self.arg(.file),')' #'>'
}

multi method arg(SAST::Concat:D $_) {
    return '""' unless .children;
    my @compiled = .children.flatmap({ self.arg($_) });
    my @strs;

    for @compiled -> $this {
        if @strs[*-1] -> $last is rw {
            if $last.ends-with('"') && $this.starts-with('"') {
                $last ~~ s/'"'$/{$this.substr(1)}/;
                next;
            }
        }
        @strs.push($this);
    }
    @strs;
}

multi method arg(SAST::Type $_,:$flat) {
    if .class-type.enum-type {
        |self.quote: (.class-type.^types-in-enum».name).join('|'),:$flat;
    } else {
        |self.quote: .gist,:$flat;
    }
}

multi method arg(SAST::Slip:D $_) {
    self.arg(.children[0],:flat)
}

multi method arg(SAST::Negative:D $_) {
    self.arg(.as-string);
}

multi method arg(SAST::Block:D $_) {
    if .one-stmt -> $return {
        self.arg($return.val);
    } else {
        self.quote: '$(',self.node($_,:one-line),')';
    }
}

multi method arg(SAST::Given:D $_) {
    self.quote: '$(',self.node($_),')';
}

multi method arg(SAST::Call:D $_) is default {
    SX::Sh::ImpureCallAsArg.new(call-name => .name,node => $_).throw if .declaration.impure;
    nextsame;
}

multi method arg(SAST:D $_,:$flat) {
    self.quote: '$(',|self.cap-stdout($_),')',:$flat;
}
multi method arg(SAST::Junction:D $_) {
    with self.try-param-substitution($_) {
        .return;
    } else {
        nextsame;
    }
}

multi method cap-stdout(ShellStatus $_) {
    |self.cond($_),' && ',self.scaf('e'),' 1';
}

multi method cap-stdout(SAST::If:D $_) {
    nextsame when ShellStatus;
    self.node($_);
}

multi method cap-stdout(SAST:D $_) {
    self.scaf('e'),' ',|self.arg($_);
}

multi method cap-stdout(SAST::Call:D $_) is default {
    nextsame when ShellStatus;
    self.node($_)
}

multi method cap-stdout(SAST::Cmd:D $_) {
    nextsame when ShellStatus;
    self.node($_);
}

multi method cap-stdout(SAST::List:D $_) {
    if .children > 1 {
        self.make-list(.children);
    } else {
        self.cap-stdout(.children[0]);
    }
}

multi method cap-stdout(SAST::Regex:D $_) {
    self.cap-stdout(.pre);
}



# Mimicking perl-like junctions in a stringy context (|| &&) in shell is tricky.
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

multi method cap-stdout(SAST::Junction:D $_) {
    self.compile-junction($_);
}

method try-param-substitution(SAST::Junction:D $junct) {
    my \LHS = $junct[0];
    my \RHS = $junct[1];
    if LHS ~~ SAST::CondReturn and LHS.val ~~ SAST::Var and LHS.val.uses-Str-Bool {
        self.quote: '${',
        self.gen-name(LHS.val),
        (LHS.when ?? ':-' !! ':+'),
        |self.arg(RHS),
        '}';
    }
}

multi method cap-stdout(SAST::CondReturn:D $_) {
    if .when === True  and !.Bool-call {
        '{ ',self.cond(.val), ' && ',self.scaf('e'), ' 1;',' }';
    } elsif .when === False and .val.uses-Str-Bool or !.Bool-call {
        # Special case shell optimization!!!
        # $(test "$foo" || { echo "$foo" && false; }  && echo "$bar")
        # can be reduced-to: (test "$foo" || echo "$bar")
        self.cond(.val);
    } else {
        self.junct-helper(.Bool-call,.when);
    }
}

multi method cap-stdout(SAST::Ternary:D $_,:$tight) {
    self.node($_,:$tight);
}

multi method int-expr(SAST:D $_) { '$(',|self.cap-stdout($_),')' }
multi method int-expr(SAST::IntExpr:D $_,:$tight) {
    ('(' if $tight),|self.int-expr(.[0]),.sym,|self.int-expr(.[1],:tight),(')' if $tight);
}
multi method int-expr(SAST::Var:D $_) {
    my $name = self.gen-name(.declaration);
    if $name.Int -> $param {
        '$',$name;
    } else {
        $name;
    }
}
multi method int-expr(SAST::Ternary:D $_) {
    # XXX: atm we will never get here
    self.int-expr(.cond), ' ? ',self.int-expr(.on-true),' : ',self.int-expr(.on-false);
}
multi method int-expr(SAST::BVal $ where { .val === False } ) { '0' }
multi method int-expr(SAST::Negative:D $_) {
    '-',|self.int-expr($_[0],:tight);
}
multi method int-expr(SAST::IVal:D $_) { .val.Str }

method comment(Str:D $_) { '# ',$_ }

method junct-helper($Bool-call is copy,$when is copy) {
    my $name = $when ?? 'et' !! 'ef';
    self.scaf($name),' ',self.cond($Bool-call);
}

method make-list(*@args){
    if @args > 1 {
        self.scaf('list'),|@args.flatmap({ ' ', |self.arg($_) });
    } else {
        return self.arg(@args[0]);
    }
}
