use Spit::SAST;
use Spit::Metamodel;
need Spit::Constants;
need Spit::Exceptions;
use Spit::Sh::ShellElement;
need Spit::Sh::Compiler::Name-Generator;
need Spit::Sh::Compiler::Compile-Junction;
need Spit::Sh::Compiler::Compile-Cmd-And-Call;
need Spit::Sh::Compiler::Compile-Statement-Control;

my %native = (
    et => Map.new((
        body => Q<"$@" && eval "printf %s \"\$$#\"">,
        deps => (),
    )),
    ef => Map.new((
        body => Q<"$@" || { eval "printf %s \"\$$#\"" && return 1; }>,
        deps => (),
    )),
);

my subset ShellStatus of SAST where {
    # 'or' and 'and' don't work here for some reason
    ($_ ~~ SAST::Neg|SAST::Cmp) ||
    ((.original-type ~~ tBool) && $_ ~~
      SAST::Stmts|SAST::Cmd|SAST::Call|SAST::If|SAST::Case|SAST::Quietly|SAST::LastExitStatus
    )
}

unit class Spit::Sh::Compiler;

has $.SETTING is required;

also does Name-Generator;
also does Compile-Junction;
also does Compile-Cmd-And-Call;
also does Compile-Statement-Control;

constant @reserved-cmds = %?RESOURCES<reserved.txt>.slurp.split("\n");

method BUILDALL(|) {
    @!names[SCALAR]<_> = '_';
    for @reserved-cmds {
        @!names[SUB]{$_} = $_;
    }
    callsame;
}

method scaffolding {
    my @a;
    for
    (SUB,'list'),
    (SCALAR,'?IFS'),
    (SUB,'et'),
    (SUB,'ef'),
    (SUB,'e')
         {
        my $sast = $!SETTING.lookup(|$_) || die "scaffolding {$_.gist} doesn't exist";
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

method scaf($name) {
    my $scaf = $*depends.require-scaffolding($name);
    $scaf.depended = True;
    self.gen-name($scaf);
}

has $!composed-for;
method compile(SAST::CompUnit:D $CU, :$one-block, :$xtrace --> Str:D) {
    my $*pad = '';
    my $*depends = $CU.depends-on;
    my ShellElement:D @compiled;

    $!composed-for = $CU.composed-for;
    my @MAIN = self.node($CU,:indent);

    my @END = flat $CU.phasers.grep(*.defined).map: {
        ("\n" if $++), |self.compile-nodes($_,:indent)
    };

    my @compiled-depends = grep *.so, $*depends.reverse-iterate: {
        self.compile-nodes([$_],:indent).grep(*.defined);
    };

    my @BEGIN = @compiled-depends && @compiled-depends.map({ ("\n" if $++),|$_}).flat;
    my @run;

    if $one-block and not @END {
        @compiled.append: |self.maybe-oneline-block:
            [
                |(|@BEGIN,"\n" if @BEGIN)
                ,|@MAIN
            ];
    } else {
        for :@BEGIN,:@MAIN {
            if .value {
                @compiled.append(.key,'()',|self.maybe-oneline-block(.value),"\n");
                @run.append(.key,' && ');
            }
        }
        @run.pop if @run; # remove last &&
    }

    if @END {
        @compiled.append:
        'END()',
        |self.maybe-oneline-block(@END),"\n",
        "trap END EXIT;" ~
        # Do nothing on after TERM is recieved a second time
        "trap 'trap : TERM; exit 1' TERM\n";
    }

    @compiled.push(“set -x\n”) if $xtrace;
    @compiled.append(|@run,"\n") if @run;
    @compiled.join("");
}

method maybe-oneline-block(@compiled) {
    my $compiled = @compiled.join;
    if $compiled.contains("\n") {
        "\{\n", $compiled,"\n$*pad\}";
    } else {
        $compiled ~~ s/^\s+//;
        '{ ', ($compiled || ':'), (';' unless $compiled.ends-with('&')),' }';
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

method arglist(@list) {
    flat @list.map: {
        (' ' if $++ ),
        (
            if !.itemize and $_ ~~  SAST::Empty {
                Empty
            }
            elsif !.itemize and $_ ~~  SAST::List {
                self.arglist(.children);
            }
            else {
                self.scaf('?IFS') unless .itemize;
                self.arg($_).itemize(.itemize);
            }
        )
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
    {*};
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
    self.scaf('list'),' ',|self.arg($_).itemize(.itemize);
}

multi method cond(SAST:D $_) {
    if .type === tInt {
        'test ',|self.arg($_), ' -ne 0';
    } else {
        'test ',|self.arg($_);
    }
}

multi method assign($var,SAST:D $_) { self.gen-name($var),'=',|self.arg($_) }

multi method int-expr(SAST:D $_) { self.arg($_).in-DQ }

#!ShellStatus
multi method node(ShellStatus:D $_) { self.cond($_) }
multi method cond(ShellStatus:D $_,|c) { self.node($_,|c) }
multi method cap-stdout(ShellStatus $_) {
    |self.cond($_),' && ',self.scaf('e'),' 1';
}
#!Var
multi method node(SAST::Var:D $var) {
    return Empty if $var ~~ SAST::ConstantDecl and not $var.depended;
    my $name = self.gen-name($var);

    with $var.assign {
        my @var = |self.assign($var,$_);
        if @var[0].starts-with('$') {
            @var.unshift(': ');
        }
        @var;
    } elsif $var ~~ SAST::VarDecl {
        if $var !~~ SAST::EnvDecl {
            $name,'=',($var.type ~~ tInt ?? '0' !! "''")
        }
    } else {
        ': $',$name;
    }
}

multi method arg(SAST::Var:D $var) {
    if $var.declaration.?slurpy {
        self.scaf('?IFS');
        return DollarAT.new;
    }
    my $name = self.gen-name($var);
    my $assign = $var.assign;
    with $assign {
        my $arg-assign := self.assign($var,$assign);
        if $arg-assign.starts-with('$') {
            dq $arg-assign;
        } else {
            SX::NYI.new(feature => 'assignment as an argument',node => $var).throw
        }
    } else {
        var $name, is-int => ($var.type ~~ tInt);
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


#!Ternary
multi method node(SAST::Ternary:D $_,:$tight) {
    ('{ ' if $tight),
    |self.cond(.cond),
    |(' && ',|self.compile-in-ctx(.on-true,:tight) unless .on-true.compile-time ~~ ()),
    |(' || ',|self.compile-in-ctx(.on-false,:tight) unless .on-false.compile-time ~~ ()),
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

multi method cap-stdout(SAST::Stmts $_, :$tight) {
    ('{ ' if $tight),
    |self.node($_,:one-line),
    ('; }' if $tight)
}

#!LastExitStatus
multi method cond(SAST::LastExitStatus:D $_) { 'test $? = 0' }

multi method arg(SAST::LastExitStatus:D $_) {
    .ctx ~~ tBool ?? callsame() !! '$?';
}

#!CurrentPID
multi method arg(SAST::CurrentPID:D $) { '$$' }

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
        |(if .signature.slurpy-param {
             my @non-slurpy =
                 (.invocant andthen (.piped ?? Empty !! $_) when SAST::MethodDeclare),
                 |.signature.pos[^(*-1)];

             if @non-slurpy {
                 "$*pad  ",
                 |flat @non-slurpy.map({
                     (" " if $++), self.gen-name($_),'=$', .shell-position.Str;
                 }),
                 " shift {+@non-slurpy}\n"
             }
        }),
        self.node(.chosen-block,:indent,:no-empty);
    }
    $name,'()',|self.maybe-oneline-block(@compiled)
}

#!Return
multi method node(SAST::Return:D $ret) {
    if $ret.return-by-var {
        'R=',self.arg($ret.val);
    } elsif $ret.loop {
        self.loop-return($ret.val);
    } else {
        # If we're returning the exit status of the last cmd we can just do nothing
        # because that's what will be retuned if we do.
        if $ret.val ~~ SAST::LastExitStatus and $ret.ctx ~~ tBool {
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
        when tBool { self.cond($node,|%_)       }
        when tStr  { self.cap-stdout($node,|%_) }
        when tAny  { self.node($node,|%_) }
        default {
            SX::Bug.new(:$node,desc => "{$node.^name}'s type context {.gist} is invalid").throw
        }
    }
}
#!Empty
multi method node(SAST::Empty:D $_) { Empty }
multi method  arg(SAST::Empty:D $_) { dq '' }
multi method cap-stdout(SAST::Empty:D $_) { ':' }

#!Quietly
multi method node(SAST::Quietly:D $_) {
    |self.node(.block,:curlies),' 2>&',|self.arg(.null)
}

#!Start
multi method node(SAST::Start:D $_) {
    |self.node(.block, :curlies), ' >&',|self.arg(.null), ' &';
}

multi method assign($var, SAST::Start:D $start) {
    |self.node($start),' ',self.gen-name($var),'=$!';
}

multi method cap-stdout(SAST::Start:D $_) {
    |self.node($_), ' ', self.scaf('e'),' $!';
}

#!Neg
multi method cond(SAST::Neg:D $_) { '! ',|self.cond(.children[0],:tight) }

#!Cmp
multi method cond(SAST::Cmp:D $cmp) {
    my $negate = False;
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
        when 'ge' { $negate = True; '<' }
        when 'le' { $negate = True; '>' }
        default { "'$_' comparison NYI" }
    }

    '[ ',('! ' if $negate),|self.arg($cmp[0])," ", escape($shell-sym)," ",|self.arg($cmp[1]),' ]';
}

#!BVal
multi method arg (SAST::BVal:D $_) { .val ?? '1' !! '""' }
multi method cond(SAST::BVal:D $_) { .val ?? 'true' !! 'false' }
multi method int-expr(SAST::BVal $ where { .val === False } ) { '0' }

constant @cats = (qqw{
    \c[smiling cat face with open mouth]
    \c[cat face with tears of joy]
    \c[smiling cat face with heart-shaped eyes]
    \c[cat face with wry smile]
    \c[kissing cat face with closed eyes]
    \c[weary cat face]
    \c[grinning cat face with smiling eyes]
    \c[crying cat face]
    \c[pouting cat face]
    \c[cat]
    \c[cat face]
    \c[tiger face]
    \c[lion face]
} xx ∞).flat.Array;


BEGIN my @cat-names = (%?RESOURCES<cat-names.txt>.slurp.split("\n") xx ∞).flat.Array;
has $!debian;
# There are three situations that determine whether we heredoc
# 1. The string ends in a newline and you want it to stay that way
#    - Don't heredoc to cat(1) as an arg because it requires command substitution
# 2. The string doesn't end in a newline and you want it to stay that way
#    - Don't heredoc into a | to command/call
# 3. You don't care either way
#    - Heredoc away!
method try-heredoc($sast, :$preserve-end) {
    if $sast ~~ SAST::SVal
           # heredocs must end in \n which is sometimes undesirable
       and ($sast.val.ends-with("\n") or not ($preserve-end // $sast.preserve-end))
       and (my @lines = $sast.val.split("\n")) > 2
       {
        $!debian ||= $!SETTING.lookup(CLASS,'Debian').class;
        # Debian's /bin/sh (dash) doesn't do nested multi-byte character heredocs 😿
        my @nekos := ($!composed-for ~~ $!debian ?? @cat-names !! @cats);
        my $cat;
        repeat { $cat =  @nekos.shift } while @lines.first(*.match(/^"\t"+$cat/));
        $cat or SX::Bug.new(
            desc => "😿 Nekos depleted - mine more nekos 😿",
            match => $sast.match
        ).throw;
        return $cat,
               ("\n\t", @lines.join("\n\t"), ("\n\t" if @lines[*-1]), "$cat\n$*pad  ");
    } else {
        Nil;
    }
}
#!SVal
multi method arg(SAST::SVal:D $_) {
    if !.preserve-end || !.val.ends-with("\n")
       and self.try-heredoc($_, :!preserve-end) -> ($delim, $body)
    {
        cs "cat <<-'$delim'",|$body
    } else {
        escape .val
    }
}
#!IVal
multi method arg(SAST::IVal:D $_) { .val.Str }
multi method int-expr(SAST::IVal:D $_) { .val.Str }

#!Case
multi method node(SAST::Case:D $_) {
    'case ', |self.arg(.in), ' in ',
    |flat(do for .patterns.kv -> $i, $re {
             "\n$*pad  ",|self.compile-case-pattern($re.patterns<case>,$re.placeholders)
             ,') ',|self.node(.blocks[$i],:one-line), ';;';
         }),
    |(.default andthen "\n$*pad  *) ", |self.node($_, :one-line), ';;'),
    "\n{$*pad}esac";
}

multi method cap-stdout(SAST::Case:D $_) { self.node($_) }

method compile-case-pattern($pattern is copy, @placeholders) {
    if @placeholders {
        $pattern = escape($pattern).in-DQ;
        my @literals = $pattern.split(/'{{' \d '}}'/);
        for @placeholders.kv -> $i, $v {
            @literals.splice: $i*2+1, 0, self.arg($v);
        }
        my @str;
        for @literals.reverse.kv -> $i, $_ {
            @str.prepend(.in-case-pattern(next => @str.head));
        }
        @str.join || "''";
    } else {
        $pattern || "''";
    }
}

#!Regex
method compile-pattern($pattern is copy,@placeholders) {
    if @placeholders {
        $pattern = escape($pattern).in-DQ;
        my @literals = $pattern.split(/'{{' \d '}}'/);
        for @placeholders.kv -> $i, $v {
            @literals.splice: $i*2+1, 0, self.arg($v);
        }
        concat @literals;
    } else {
        escape $pattern
    }

}
multi method arg(SAST::Regex:D $_) {
    self.compile-pattern(.patterns{.regex-type}, .placeholders);
}

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

#!Concat
multi method arg(SAST::Concat:D $_) {
    concat .children.map({ self.arg($_) }).flat;
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
        self.scaf('list'),' ',|self.arglist(.children);
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

#!Pair
multi method arg(SAST::Pair:D $_) {
    concat [self.arg(.key),"\t",self.arg(.value)]
}

#!EvalArg
multi method arg(SAST::EvalArg:D $_) {
    # Don't quote had to be invented just for this
    # It means it breaks out of "" quotes if it's put in one like:
    # "foo"'dontquote'"bar"
    DontQuote.new(str => "'{.placeholder}'");
}
#!Doom
# If we try and compile Doom we're doomed
multi method arg(SAST::Doom:D $_)  { .exception.throw }

multi method arg(SAST::NAME:D $_) {
    if try self.gen-name($_[0]) -> $name {
        escape $name;
    } else {
        SX.new(message => 'value doesn\'t have name', node => $_[0]).throw;
    }
}
