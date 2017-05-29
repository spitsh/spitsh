need Spit::Exceptions;
need Spit::Parser::Lang;
need Spit::Parser::Quote;
use Spit::Constants;
need Spit::Parser::Regex;
need Spit::SpitDoc;

# ripped form rakudo
constant @brackets := "<>[]()\{}\x[0028]\x[0029]\x[003C]\x[003E]\x[005B]\x[005D]\x[007B]\x[007D]\x[00AB]\x[00BB]\x[0F3A]\x[0F3B]\x[0F3C]\x[0F3D]\x[169B]\x[169C]\x[2018]\x[2019]\x[201A]\x[2019]\x[201B]\x[2019]\x[201C]\x[201D]\x[201E]\x[201D]\x[201F]\x[201D]\x[2039]\x[203A]\x[2045]\x[2046]\x[207D]\x[207E]\x[208D]\x[208E]\x[2208]\x[220B]\x[2209]\x[220C]\x[220A]\x[220D]\x[2215]\x[29F5]\x[223C]\x[223D]\x[2243]\x[22CD]\x[2252]\x[2253]\x[2254]\x[2255]\x[2264]\x[2265]\x[2266]\x[2267]\x[2268]\x[2269]\x[226A]\x[226B]\x[226E]\x[226F]\x[2270]\x[2271]\x[2272]\x[2273]\x[2274]\x[2275]\x[2276]\x[2277]\x[2278]\x[2279]\x[227A]\x[227B]\x[227C]\x[227D]\x[227E]\x[227F]\x[2280]\x[2281]\x[2282]\x[2283]\x[2284]\x[2285]\x[2286]\x[2287]\x[2288]\x[2289]\x[228A]\x[228B]\x[228F]\x[2290]\x[2291]\x[2292]\x[2298]\x[29B8]\x[22A2]\x[22A3]\x[22A6]\x[2ADE]\x[22A8]\x[2AE4]\x[22A9]\x[2AE3]\x[22AB]\x[2AE5]\x[22B0]\x[22B1]\x[22B2]\x[22B3]\x[22B4]\x[22B5]\x[22B6]\x[22B7]\x[22C9]\x[22CA]\x[22CB]\x[22CC]\x[22D0]\x[22D1]\x[22D6]\x[22D7]\x[22D8]\x[22D9]\x[22DA]\x[22DB]\x[22DC]\x[22DD]\x[22DE]\x[22DF]\x[22E0]\x[22E1]\x[22E2]\x[22E3]\x[22E4]\x[22E5]\x[22E6]\x[22E7]\x[22E8]\x[22E9]\x[22EA]\x[22EB]\x[22EC]\x[22ED]\x[22F0]\x[22F1]\x[22F2]\x[22FA]\x[22F3]\x[22FB]\x[22F4]\x[22FC]\x[22F6]\x[22FD]\x[22F7]\x[22FE]\x[2308]\x[2309]\x[230A]\x[230B]\x[2329]\x[232A]\x[23B4]\x[23B5]\x[2768]\x[2769]\x[276A]\x[276B]\x[276C]\x[276D]\x[276E]\x[276F]\x[2770]\x[2771]\x[2772]\x[2773]\x[2774]\x[2775]\x[27C3]\x[27C4]\x[27C5]\x[27C6]\x[27D5]\x[27D6]\x[27DD]\x[27DE]\x[27E2]\x[27E3]\x[27E4]\x[27E5]\x[27E6]\x[27E7]\x[27E8]\x[27E9]\x[27EA]\x[27EB]\x[2983]\x[2984]\x[2985]\x[2986]\x[2987]\x[2988]\x[2989]\x[298A]\x[298B]\x[298C]\x[298D]\x[298E]\x[298F]\x[2990]\x[2991]\x[2992]\x[2993]\x[2994]\x[2995]\x[2996]\x[2997]\x[2998]\x[29C0]\x[29C1]\x[29C4]\x[29C5]\x[29CF]\x[29D0]\x[29D1]\x[29D2]\x[29D4]\x[29D5]\x[29D8]\x[29D9]\x[29DA]\x[29DB]\x[29F8]\x[29F9]\x[29FC]\x[29FD]\x[2A2B]\x[2A2C]\x[2A2D]\x[2A2E]\x[2A34]\x[2A35]\x[2A3C]\x[2A3D]\x[2A64]\x[2A65]\x[2A79]\x[2A7A]\x[2A7D]\x[2A7E]\x[2A7F]\x[2A80]\x[2A81]\x[2A82]\x[2A83]\x[2A84]\x[2A8B]\x[2A8C]\x[2A91]\x[2A92]\x[2A93]\x[2A94]\x[2A95]\x[2A96]\x[2A97]\x[2A98]\x[2A99]\x[2A9A]\x[2A9B]\x[2A9C]\x[2AA1]\x[2AA2]\x[2AA6]\x[2AA7]\x[2AA8]\x[2AA9]\x[2AAA]\x[2AAB]\x[2AAC]\x[2AAD]\x[2AAF]\x[2AB0]\x[2AB3]\x[2AB4]\x[2ABB]\x[2ABC]\x[2ABD]\x[2ABE]\x[2ABF]\x[2AC0]\x[2AC1]\x[2AC2]\x[2AC3]\x[2AC4]\x[2AC5]\x[2AC6]\x[2ACD]\x[2ACE]\x[2ACF]\x[2AD0]\x[2AD1]\x[2AD2]\x[2AD3]\x[2AD4]\x[2AD5]\x[2AD6]\x[2AEC]\x[2AED]\x[2AF7]\x[2AF8]\x[2AF9]\x[2AFA]\x[2E02]\x[2E03]\x[2E04]\x[2E05]\x[2E09]\x[2E0A]\x[2E0C]\x[2E0D]\x[2E1C]\x[2E1D]\x[2E20]\x[2E21]\x[2E28]\x[2E29]\x[3008]\x[3009]\x[300A]\x[300B]\x[300C]\x[300D]\x[300E]\x[300F]\x[3010]\x[3011]\x[3014]\x[3015]\x[3016]\x[3017]\x[3018]\x[3019]\x[301A]\x[301B]\x[301D]\x[301E]\x[FD3E]\x[FD3F]\x[FE17]\x[FE18]\x[FE35]\x[FE36]\x[FE37]\x[FE38]\x[FE39]\x[FE3A]\x[FE3B]\x[FE3C]\x[FE3D]\x[FE3E]\x[FE3F]\x[FE40]\x[FE41]\x[FE42]\x[FE43]\x[FE44]\x[FE47]\x[FE48]\x[FE59]\x[FE5A]\x[FE5B]\x[FE5C]\x[FE5D]\x[FE5E]\x[FF08]\x[FF09]\x[FF1C]\x[FF1E]\x[FF3B]\x[FF3D]\x[FF5B]\x[FF5D]\x[FF5F]\x[FF60]\x[FF62]\x[FF63]".comb;

constant @openers = eager @brackets.map: -> $o,$ { $o };

constant $gt-comma = «g>»; #greater than , precedence
constant $gt-fatarrow = «i>»;

grammar Spit::Grammar is Spit::Lang {
    token TOP {
        :my $*CURPAD;
        :my $*CU;
        :my $*ENDSTMT;
        :my @*PRE-DOC;
        :my %*SEEN-DOC;
        {
            # Just copied this "define_slang" from what TimToady did with rakudo.
            # It seems to store grammar/action pairs.
            self.define_slang("MAIN",self,$*ACTIONS);
            self.define_slang("Quote-Q", Spit::Quote, Spit::Quote::Actions);
            for <q qq> {
                self.define_slang("Quote-$_",Spit::Quote::{$_},Spit::Quote::{$_ ~ '-Actions'});
            }
            self.define_slang('Regex',Spit::Regex, Spit::Regex-Actions);
        }
        <.newCU>
        ^
        <statementlist>
        [$<unbalanced>=\S+ { SX::Unexpected.new(match => $<unbalanced>).throw } ]?
        $
    }

    token opener { @openers }

    token newpad { <?> }
    token finishpad { <?> }
    token newCU { <.newpad> }

    token statementlist {
        [<.ws> <statement> <.eat-terminator> ]* <.ws>
    }

    token eat-terminator {
        || <?{$*ENDSTMT ?? ($*ENDSTMT = False; True) !! False}>
        || <.terminator>
        || <.expected("terminator", ';')>
    }

    token terminator {
        | <.ws> $
        | <.ws> ';'
        | <.ws> <?before '}'|')'>
    }

    token ENDSTMT {
        [
            [
                | \h* $$
                | \h* <.comment> $$
            ]
            <.ws> { $*ENDSTMT = True }
        ]?
    }

    token statement {
        <!before <[\])}]> | $ >
        [
            $<statement>=(
                | <pragma>
                | <declaration>
                | <statement-control>
                | <statement-prefix>
                | {} <EXPR-and-mod>
            )
            | <?[;]>
            | {} <.invalid: "statement">
        ]
    }

    rule EXPR-and-mod {
        <EXPR> [
            || <?{ $*ENDSTMT }>
            || <statement-mod-cond>? <statement-mod-loop>?
        ]?
    }

    token hyphen { '-' }

    token identifier {
        <.ident> [ <.hyphen> <.ident> ]*
    }

    proto token pragma {*}

    rule pragma:sym<use> {
        <sym>
        [
            || 'lib' <.ws> <.NYI("use lib")>
            || $<repo-type>=<.identifier><angle-quote>
            || <identifier>
        ]

    }

    rule pragma:sym<require> {
        <sym> <.NYI("require statement")>
    }

    proto token statement-prefix {*}

    constant @phaser-names = eager Spit-Phaser::.keys;
    rule statement-prefix:phaser {
        $<sym>=@phaser-names <blorst>
    }

    rule statement-prefix:sym<quietly> {
        <.sym> <blorst>
    }

    rule statement-prefix:sym<start> {
        <.sym> <blorst>
    }

    proto token statement-mod-cond {*}
    rule statement-mod-cond:sym<if> { $<sym>=['if'|'unless'] <EXPR> }

    proto token statement-mod-loop {*}
    rule statement-mod-loop:sym<for> { <sym> <list> }
    rule statement-mod-loop:sym<while> { $<sym>=['while'|'until'] <EXPR> }

    proto token statement-control {*};
    rule statement-control:sym<if> {
        $<sym>=['if'|'unless'] <EXPR> ['->' <var-and-type('topic')>]? <block>
        ['' 'elsif' $<elsif>=( <EXPR> <block>)]*
        ['else' $<else>=<.block>]?
    }
    rule statement-control:sym<loop> {
        <sym> $<loop-spec>=<.wrap: '(', ')', 'loop specification', rule {
            $<init>=<.EXPR>? ';'
            $<cond>=<.EXPR>? ';'
            $<incr>=<.EXPR>?
         }>?
        <block>
    }

    rule statement-control:sym<for> {
        <sym> <list> ['->' <var-and-type>]? <block>
    }

    rule statement-control:sym<while> {
        $<sym>=['while'|'until'] <EXPR> ['->' <var-and-type('topic')>]? <block>
    }

    rule statement-control:sym<given> {
        <sym> <EXPR> <block>
    }

    rule statement-control:sym<when> {
        (
            <.sym>
            [
                <EXPR> <block>
                ||
                <.invalid('when statement')>
            ]
            |
            'default' <block>
        )+
    }

    rule statement-control:sym<on> {
        <on-switch>
    }

    proto token declaration {*}

    rule new-class {
        <type-name>
        $<params>=<.r-wrap: '[',']', 'class parameter list', rule {
            <type-name>* % ','
        }>?
    }
    token declare-class-params { <?> }
    rule declaration:sym<class> {
        :my $*CLASS;
        <sym> <new-class>
        :my $*DECL = $*CLASS;
        <.attach-pre-doc>
        <trait>*
        <.newpad>
        <.declare-class-params>
        <blockoid>
        <.finishpad>
    }

    token old-class { <type> }
    rule declaration:sym<augment> {
        :my $*CLASS;
        <sym> <old-class>
        :my $*DECL = $*CLASS;
        <.attach-pre-doc>
        <.newpad>
        <.declare-class-params>
        <blockoid>
        <.finishpad>
    }

    rule new-enum-class { <type-name> }
    rule declaration:sym<enum-class> {
        :my $*CLASS;
        <sym> <new-enum-class>
        :my $*DECL = $*CLASS;
        <.attach-pre-doc>
        <trait>* <block>
    }

    proto token trait {*}

    rule trait:sym<is> {
        <sym>
        [
            |$<primitive>='primitive'
            |$<native>='native'
            |$<export>='export'
            |$<no-inline>='no-inline'
            |$<rw>='rw'
            |$<return-by-var>='return-by-var'
            |$<impure>='impure'
            |{} <type>
        ]
    }


    rule declaration:sym<sub> {
        <sym>
        :my $*ROUTINE;
        <routine-declaration('sub')>
    }

    rule declaration:sym<method> {
        [$<static>='static']? <sym>
        :my $*ROUTINE;
        {} <routine-declaration('method',static => $<static>:exists)>
    }

    rule routine-declaration(|c){
        <.newpad>
        :my $*DECL;
        <.new-routine(|c)>
        <trait>*
        [ <on-switch> || <cmd-blockoid> || <.expected("on switch or block to define routine")>]
        <.finishpad>
    }

    token longarrow {['-->'| '⟶']}
    rule new-routine(|c){
        $<name>=<.identifier>
        { $*DECL = $*ACTIONS.make-routine($/,|c) }
        <.attach-pre-doc>
        [
            $<param-def>=<.r-wrap:'(',')', 'parameter list', rule {
                <paramlist>
                (<.longarrow> <.panic("Return type inside signature. Put it outside (...)⟶Type.")>)?
            }>
        ]?

        [
            |[
                <.longarrow> [
                    || $<return-type>=<.type>
                    || \s <.panic('No whitespace allowed after ⟶')>
                    || <.invalid('return type')>
                ]
            ]
            |<return-type-sigil>
        ]?
    }

    rule on-switch {
        'on' $<candidates>=<.wrap: '{','}','on switch', rule {
            (
                <!before '}'>
                [<os> || <.expected('OS name')> ]
                [<cmd-block> || <.expected("A block for { $<os>.Str }")>]
            )*
        }>
    }

    rule declaration:var {
        $<sym>=['constant'|'my'|'env']
        {} <var-and-type($<sym>.Str)>
        :my $*DECL;
        { $*DECL = $<var-and-type>.ast }
        <trait>* [
            || '=' <.attach-pre-doc> <statement>
            || <?terminator> <.attach-pre-doc>
        ]
    }

    proto token return-type-sigil {*};
    token return-type-sigil:sym<~> { <sym> }
    token return-type-sigil:sym<+> { <sym> }
    token return-type-sigil:sym<?> { <sym> }
    token return-type-sigil:sym<@> { <sym> }
    token return-type-sigil:sym<*> { <sym> }

    rule signature {
        <paramlist>
    }
    rule paramlist {
        :my $*DECL;
        $<params>=(
            <param>
            { $*DECL = $<param>.ast }
            <.attach-pre-doc>
        )* % ','
    }

    token param {
        [
            | $<pos>=[ <type>? <.ws> $<slurpy>='*'?<var> ]
            | $<named>=[ <type>? <.ws> ':'<var> ]
        ]
        [$<optional>='?'| <.ws> '=' <.ws> $<default>=<.EXPR($gt-comma)>]?
    }

    rule check-prec($min-precedence,$term) {
        <?before
            $<check>=<.infix>
            {}
            <?{ not $<check> # ie no infix was found
                or $<check>.&derive-precedence($term)[0] ge $min-precedence }>
        >
    }

    rule EXPR($min-precedence?) {
        <termish>
        [
            [ <!{ $min-precedence }> || {} <.check-prec($min-precedence,$<termish>[*-1].ast)> ]
            <infix>
            [ <termish>  || {}<.expected("term after infix {$<infix>[*-1]<sym>.Str}")>  ]
        ]*
    }

    rule list {
        <EXPR($gt-comma)>* % ','
    }
    rule args {
        [$<named>=<.pair> || $<pos>=<.EXPR($gt-comma)> ]* % ','
    }

    token termish {
        || <term> [<.ws><postfix>]*
        || [<prefix><.ws>]+ <term> [<.ws><postfix>]*
    }

    proto token term {*}
    token term:true { 'True' }
    token term:false { 'False' }
    token term:quote { <quote> }
    token term:angle-quote { <angle-quote> }
    token term:int { <int> }
    token int { \d+ }
    token term:var { <var> }
    token var {
        <sigil>
        [
            | [
                |$<name>=(<twigil>?<identifier>)
                |$<name>='/' <?{ $<sigil>.Str eq '@' }>
                |$<name>='~' <?{ $<sigil>.Str eq '$' }>
              ]
            | <?after '$'> <special-var>
        ]
    }

    proto token special-var {*}
    token special-var:sym<?> { <sym> }

    proto token twigil {*}
    token twigil:sym<*> { <sym> }
    token twigil:sym<?> { <sym> }
    token term:block { <block>  }
    token term:sym<self>  {
        <sym>
        { SX.new(message => 'Use of Perl 6 sytle invocant. In Spit use ‘$self’').throw }
    }
    token term:name {
        $<name>=<.identifier> {}
        [
            <?{ $*CURPAD.lookup(CLASS,$<name>.Str); }>
            $<is-type>=<?>
            <type-params>?
            $<object>=(
                |<angle-quote>
                | $<EXPR>=<.r-wrap: '(',')','object definition', token {
                      <R=.EXPR>
                  }>
            )?
            ||
            $<call-args>=(
                | $<args>=<.r-wrap: '(',')',"call to {$<name>.Str}'s arguments", token {
                      <R=.args>
                  }>
                | \s+ <args>
            )?
        ]
    }

    rule  term:my  {
        'my' <var-and-type>
    }
    rule var-and-type($decl-type = 'my') {
        <type>? <var>
        {
            if $<var><special-var> {
                self.invalid("variable declaration. You can't declare a special variable");
            }
            $/.make($*ACTIONS.var-create($/,$decl-type) )
        }
    }

    token term:pair { <pair> }

    token pair {
        |$<pair>=<.colon-pair>
        |$<pair>=<.fatarrow-pair>
    }

    token colon-pair {
        ':'
        [
            |$<key>=<.identifier> [
                | $<value>=<.wrap: '(',')', 'pair value', token {<R=.EXPR>}>
                | $<value>=<.angle-quote>
            ]?
            |<var>
        ]
    }

    token fatarrow-pair {
        $<key>=<.identifier>
        \h*'=>'<.ws>
        $<value>=<.EXPR($gt-fatarrow)>
    }

    token term:parens {
        $<statementlist>=<.wrap: '(',')', 'parenthesized expression', rule {
            '' <R=.statementlist>
        }>
    }

    rule term:cmd { <cmd> }
    rule term:cmd-capture { '\\'<cmd> }

    # .call for @something
    rule term:topic-call { <method-call> }
    # -->Pkg.install unless Cmd<curl>
    rule term:topic-cast {
        <.longarrow> [ <type> || <.expected('A type to cast $_ to')> ]
    }

    rule term:j-object {
        'j' $<pairs>=<.wrap: '{', '}', 'json object', rule {
             '' <pair>* % ','
         }>
    }

    proto token eq-infix {*}

    token eq-infix:sym<&&> { <sym>  }
    token eq-infix:sym<||> { <sym>  }
    token eq-infix:sym<and> { <sym> }
    token eq-infix:sym<or>  { <sym> }
    token eq-infix:sym<~>   { <sym> }
    token eq-infix:intexpr { $<sym>=['+'|'-' <!before '>'> |'*'|'/'] } #'

    proto token infix {*};

    token infix:eq-infix { $<sym>=<eq-infix> <!before '='> }
    token infix:sym<=> { <eq-infix>?<sym> <!before \>> }
    token infix:sym<.=>  { <sym> }
    token infix:sym<,>   { <sym> }
    token infix:sym<~~> { <sym> }

    token infix:comparison {
        $<sym>=[
            '=='|'!='|'>'
            |'<' [ <?after \s'<'> || { SX.new(message => "infix '<' requires a space before it").throw } ] #>
            |'>='|'<='|
            'eq'|'ne'|'gt'|'lt'|'le'|'ge'
        ]
    }

    token infix:sym<..>  { [$<exclude-start>='^']? <sym> [$<exclude-end>='^']? }

    rule  infix:sym<?? !!> {
        $<sym>='??' <EXPR('j=')> ['!!' || <.expected('!! to finish ternary')> ]
    }

    token infix:sym«=>» { <sym> }

    proto token postfix {*}

    token method-call {
        '.'<.ws>$<name>=<.identifier>
        [
            |':' <.ws> <args>
            |$<args>=<.r-wrap: '(',')','method call arguments', token {
                <R=.args>
            }>
        ]?
    }

    token postfix:method-call { <method-call> }

    token postfix:cmd-call {
        '.'<.ws><cmd>
    }

    token postfix:sym<++>  { <sym> }
    token postfix:sym<-->  { <sym> <!before \>> }
    token postfix:sym<⟶> { <.longarrow> [<type> || <.expected("A type to cast to.")>] }
    token postfix:sym<[ ]> { <!after \s> <index-accessor> }

    token index-accessor {
        $<EXPR>=<.wrap: '[',']','index accessor', token { <R=.EXPR> }>
    }

    token postfix:sym<{ }> { <!after \s> <key-accessor> }

    token key-accessor {
        $<EXPR>=<.wrap: '{','}', 'key accessor', token { <R=.EXPR> }>
    }
    token postfix:sym«< >» { <!after \s> <angle-key-accessor> }
    token angle-key-accessor { <angle-quote> }

    proto token prefix {*}
    token prefix:sym<++> { <sym> }
    token prefix:sym<--> { <sym> }
    token prefix:sym<~>  { <sym> }
    token prefix:sym<+>  { <sym> }
    token prefix:sym<->  { <sym> }
    token prefix:sym<?>  { <sym> }
    token prefix:sym<!>  { <sym> }
    token prefix:sym<|>  { <sym> }
    token prefix:sym<^>  { <sym> }
    token prefix:i-sigil { <sigil> <?before <.sigil>|'('> }

    proto token sigil {*}
    token sigil:sym<$> { <sym> }
    token sigil:sym<@> { <sym> }

    # requires a <.newpad> before invocation
    # and a <.finishpad> after
    token blockoid {
        $<statementlist>=<.wrap: '{','}','block', token { <R=.statementlist> }>
        <.ENDSTMT>
    }

    token cmd-blockoid {
        | <cmd> <.ENDSTMT>
        | <blockoid>
    }

    token cmd-block {
        <?[${]> <.newpad> <cmd-blockoid> <.finishpad>
    }

    token block {
        <?[{]> <.newpad> <blockoid> <.finishpad>
    }

    token blorst {
        [ <?[{]> <block> | <![;]> <statement> || <.expected: 'block or statement'> ]
    }

    token type { <type-name>[<parameter-index> || <type-params> ]? }

    rule parameter-index {
        '[' ~ ']' $<index>=\d+
    }

    token type-params {
        $<params>=<.r-wrap: '[',']', 'type parameter list', rule {
            <type>* % ','
        }>
    }

    token os {
        <identifier>
        <?{ $*CURPAD.lookup(CLASS,$<identifier>.Str,:match($<identifier>)) }>
        #TODO: make sure it's a os
     }
    token type-name { <.identifier> }

    token cmd {
        $<cmd-pipe-chain>=<.wrap: '${','}','command', rule { <R=.cmd-pipe-chain> },>
    }

    token cmd-pipe-chain {
        [ <.ws> <cmd-body> <.ws> ]+ % '|'
    }

    token cmd-body {
        [<!before <.ws><[|}]>> <cmd-arg> ]+ %
        [\s<.ws> || (',' <.invalid("comma in command arguments. Use whitespace to separate arguemnts")>) ]
    }

    token cmd-arg {
        | <cmd-term>
        | <redirection>
        | $<pair>=<::("term:pair")>
        | $<bare>=[\w+|<.hyphen>]+
        | {} <.invalid('command argument. Try putting "(...)" around expressions')>
    }

    token cmd-term {
        $<i-sigil>=<::('prefix:i-sigil')>*
        (<var> | $<parens>=<::("term:parens")> <![<>›‹]> | <quote> | <cmd> )
        <postfix>*
    }

    token redirection {
        $<src>=(
            |$<all>='*'
            |$<fd>=<.wrap: '(',')','redirection left-hand-side', token { <R=.EXPR> }>
            |$<err>='!'
        )?
        [$<append>='>>' | $<write>=<[>›]> | $<in>=<[<‹]>]
        $<dst>=(
            | $<null>='X'
            | $<cap>='~'
            | $<err>='!'
            | {} <.ws> [$<fd>=<.cmd-term> ||
                        <.invalid('redirection right-hand-side. Try putting "(...)" around expressions')>]
        )
    }

    proto token quote {*}

    token quote:double-quote {
        $<str>=<.wrap: '"','"', 'double-quoted string', token {
            <R=.LANG('Quote-qq',:opener('"'),:closer('"'),:tweaks<curlies>)>
        }>
    }

    token quote:curly-double-quote {
        $<str>=<.wrap: '“','”', 'double-quoted string', token {
            <R=.LANG('Quote-qq',:opener('“'),:closer('”'),:tweaks<curlies>)>
        }>
    }

    token quote:single-quote {
        $<str>=<.wrap: "'", "'",'quoted string', token {
            <R=.LANG('Quote-q',:opener("'"),:closer("'"))>
        }>
    }

    token quote:curly-single-quote {
        $<str>=<.wrap: "‘","’", 'quoted string', token {
            <R=.LANG('Quote-q',:opener("‘"),:closer("’"))>
        }>
    }

    token quote:half-bracket-quote {
        $<str>=<.wrap: '｢','｣', '｢..｣ quoted string', token {
            <R=.LANG('Quote-Q', :opener('｢'), :closer('｣'))>
        }>
    }

    token quote:sym<qq> {
        <sym> » $<str>=<.balanced-quote('Quote-qq',:tweaks<curlies>)>
    }

    token quote:sym<q> {
        <sym> »
        $<str>=<.balanced-quote('Quote-q')>
    }

    token quote:sym<Q> {
        <sym> »
        $<str>=<.balanced-quote('Quote-Q')>
    }
    # called when you know the next character is some kind of openning quote
    # but you don't know what it is yet.
    token balanced-quote($lang,:$tweaks,:$bracket-only) {
        :my $closer;
        :my $opener;
        :my @tweaks;
        [
            |<opener>
            |<!{$bracket-only}> $<open-and-close>=[<!before <.hyphen>|<.identifier>> .]
        ]
        {
            @tweaks = .Slip with $tweaks;
            if $<opener> {
                $opener = $<opener>.Str;
                my $i = @brackets.first($opener,:k);
                $closer = @brackets[$i + 1];
                # Rakudo remove curlies if our balnced quote is actually curlies so we do too.
                @tweaks .= grep({ $_ ne 'curlies' }) if $opener eq '{';
            } else {
                $closer = $opener = $<open-and-close>.Str;
            }
        }

        $<str>=<.LANG($lang,:$opener,:$closer,:tweaks(|@tweaks,'balanced'))>
        <closer: $<opener> // $<open-and-close>, $closer, :desc($lang.lc)>
    }

    token angle-quote {
        ['<'\s*] ~ [\s*'>'] $<str>=<-[>]>*
    }

    token quote:sym<eval> {
        <sym>
        [$<args>=<.r-wrap:'(',')', 'eval arguemnts', token { <R=.args> }>]?
        <balanced-quote('Quote-q')>
    }

    token quote:regex {
        |$<str>=<.wrap: '/','/','regex', token { <R=.LANG('Regex',:closer</>)> }>
        |'rx' $<str>=<.balanced-quote('Regex')>
    }

    token ws {
        [
            | \s+
            | <comment>
        ]*
    }

    proto token comment {*}

    token comment:sym<#> {
        '#' {} \N*
    }

    token comment:sym<#|> {
        '#|' [
              || $<doc>=<.doc-bracket>
              || ' '? $<doc>=(\N* { $/.make(SpitDoc.new()) })
            ]
        {
            without %*SEEN-DOC{$/.from} {
                @*PRE-DOC.append($<doc>.ast);
                $_ = self.from;
            }
        }
    }

    token doc-bracket {
        <balanced-quote('Quote-q',:bracket-only,:tweaks<align-indent>)>
        {
            my $match = $<balanced-quote><str>;
            $/.make: do if $<balanced-quote><opener>.Str eq '{' {
                SpitDoc::Code.new($match.ast.compile-time,:$match);
            } else {
                SpitDoc.new($match.ast.compile-time,:$match);
            }
        }
    }

    token attach-pre-doc {
        <?> { if @*PRE-DOC { $*DECL.docs.append(@*PRE-DOC); @*PRE-DOC = (); } }
    }

    token wrap($o,$c,$desc,$wrapped) {
        $<o>=$o [ $<wrapped>=$wrapped || <.invalid($desc)> ]
        {} <closer($<o>,$c,:$desc)>
    }

    rule r-wrap($o,$c,$desc,$wrapped) {
        $<o>=$o [ $<wrapped>=$wrapped || <.invalid($desc)> ]
        {} <closer($<o>,$c,:$desc)>
    }
    token closer($opener,$closer,:$desc) {
        [$closer || { SX::Unbalanced.new(:$closer,:$opener,:$desc).throw } ]
    }

}
