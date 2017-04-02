need Spit::Parser::Lang;
# A lot of this copied from NQP p5 regex.
# Lots of p5 regex stuff not parsed properly.
# The purpose of this is to see if we can 'downgrade' the regex
# to a shell pattern or extended grep like regex.

grammar Spit::P5Regex is Spit::Lang {
    token TOP {
        :my %*RX;
        :my $*INTERPOLATE := 1;
        <nibbler>
    }

    token nibbler {
        :my $OLDRX := CALLERS::<%*RX>;
        :my %*RX;
        {
            for $OLDRX { %*RX{$_.key} := $_.value; }
        }
        <alternation>*
    }
    token sequence {
        :my $*prev-atom;
        <quantified_atom>+
    }
    token alternation {
        <sequence>+ % $<sym>='|'
    }
    token quantified_atom {
        <![|)]>
        <atom>
        [ <.ws> <quantifier=p5quantifier> ]?
        <.ws>
    }
    token atom {
        [
            | \w
            | <metachar=p5metachar>
            | {} \W
        ]
    }
    proto token p5metachar {*}
    token p5metachar:sym<quant> {
        <![(?]>
        <quantifier=p5quantifier>
        <.panic: "quantifier quantifies nothing">
    }
    token p5metachar:sym<bs> { \\ <backslash=p5backslash> }
    token p5metachar:sym<.>  { <sym> }
    token p5metachar:sym<^>  { <sym> }
    token p5metachar:sym<$>  {
        '$' <?before \W | $>
    }
    token p5metachar:sym<(? )> {
        '(?' <![?]>
        [
            | <?[<]> '<' $<name>=[<-[>]>+] '>' {} <nibbler> # >'
            | <?[']> "'" $<name>=[<-[']>+] "'" {} <nibbler> #"
            | <assertion=p5assertion>
        ]
        [ ')' || <.panic: "Perl 5 named capture group not terminated by parenthesis"> ]
    }
    token p5metachar:sym<(?: )> { '(?:' {} <nibbler> ')' }
    token p5metachar:sym<( )> { '(' {} <nibbler> ')' }
    token p5metachar:sym<[ ]> { <?before '['> <cclass> }
    token p5metachar:sym<var> {
        <?[$]> [$<backref>=\d+]
    }
    token cclass {
        :my $astfirst = 0;
        '['
        $<sign>='^'?
        [
        || $<charspec>=(
               ( '\\' <backslash=p5backslash> || (<?{ $astfirst == 0 }> <-[\\]> || <-[\]\\]>) )
               [
                   \s* '-' \s*
                   ( '\\' <backslash=p5backslash> || (<-[\]\\]>) )
               ]**0..1
               { $astfirst++ }
           )+
           ']'
        || <.panic: "failed to parse character class; unescaped ']'?">
        ]
    }

    proto token p5backslash { <...> }

    token p5backslash:sym<A> { <sym> }
    token p5backslash:sym<b> { $<sym>=[<[bB]>] }
    token p5backslash:sym<r> { <sym> }
    token p5backslash:sym<R> { <sym> }
    token p5backslash:sym<s> { $<sym>=[<[dDnNsSwW]>] }
    token p5backslash:sym<t> { <sym> }
    token p5backslash:sym<x> {
        <sym>
        [
        |           $<hexint>=[ <[ 0..9 a..f A..F ]>**0..2 ]
        | '{' ~ '}' $<hexint>=[ <[ 0..9 a..f A..F ]>* ]
        ]
    }
    token p5backslash:sym<z> { <sym> }
    token p5backslash:sym<Z> { <sym> }
    token p5backslash:sym<Q> { <sym> <!!{ $*INTERPOLATE := 0; 1 }> }
    token p5backslash:sym<E> { <sym> <!!{ $*INTERPOLATE := 1; 1 }> }
    token p5backslash:sym<misc> { $<litchar>=(\W) | $<number>=(\d+) }
    token p5backslash:sym<oops> { <.panic: "Unrecognized Perl 5 regex backslash sequence"> }

    proto token p5assertion { <...> }

    token p5assertion:sym«<» { <sym> $<neg>=['='|'!'] [ <?before ')'> | <nibbler> ] } #'>
    token p5assertion:sym<=> { <sym> [ <?before ')'> | <nibbler> ] }
    token p5assertion:sym<!> { <sym> [ <?before ')'> | <nibbler> ] }

    token p5mod  { <[imsox]>* }
    token p5mods { <on=p5mod> [ '-' <off=p5mod> ]**0..1 }
    token p5assertion:sym<mod> {
        :my %*OLDRX := CALLERS::<$*RX>;
        :my %*RX;
        {
            for %*OLDRX { %*RX{$_.key} := $_.value; }
        }
        <mods=p5mods>
        [
        | ':' <nibbler>**0..1
        | <?before ')' >
        ]
    }

    proto token p5quantifier { <...> }
    token p5quantifier:sym<*>  { <sym> <quantmod> }
    token p5quantifier:sym<+>  { <sym> <quantmod> }
    token p5quantifier:sym<?>  { <sym> <quantmod> }
    token p5quantifier:sym<{ }> {
        '{'
        $<start>=[\d+]
        [ $<comma>=',' $<end>=[\d*] ]**0..1
        '}' <quantmod>
    }

    token quantmod { [ '?' | '+' ]? }

    token ws {
        [
            | '(?#' ~ ')' <-[)]>*
            | <?{ %*RX<x> }> [ \s+ | '#' \N* ]
        ]*
    }
    token normspace { <?before \s | '#' > <.ws> }

    token identifier { <.ident> [ <[\-']> <.ident> ]* }

    token arg {
        [
        | <?[']> <quote_EXPR: ':q'>
        | <?["]> <quote_EXPR: ':qq'>
        | $<val>=[\d+]
        ]
    }

    rule arglist { <arg> [ ',' <arg>]* }

    proto token metachar { <...> }
    token metachar:sym<'> { <?[']> <quote_EXPR: ':q'> }
    token metachar:sym<"> { <?["]> <quote_EXPR: ':qq'> }
    token metachar:sym<lwb> { $<sym>=['<<'|'«'] }
    token metachar:sym<rwb> { $<sym>=['>>'|'»'] }
    token metachar:sym<from> { '<(' }
    token metachar:sym<to>   { ')>' }



    proto token backslash { <...> }
    token backslash:sym<e> { $<sym>=[<[eE]>] }
    token backslash:sym<f> { $<sym>=[<[fF]>] }
    token backslash:sym<h> { $<sym>=[<[hH]>] }
    token backslash:sym<r> { $<sym>=[<[rR]>] }
    token backslash:sym<t> { $<sym>=[<[tT]>] }
    token backslash:sym<v> { $<sym>=[<[vV]>] }
    token backslash:sym<o> { $<sym>=[<[oO]>] [ <octint> | '[' <octints> ']' ] }
    token backslash:sym<x> { $<sym>=[<[xX]>] [ <hexint> | '[' <hexints> ']' ] }
    token backslash:sym<c> { $<sym>=[<[cC]>] <charspec> }
    token backslash:sym<A> { 'A' <.obs: '\\A as beginning-of-string matcher', '^'> }
    token backslash:sym<z> { 'z' <.obs: '\\z as end-of-string matcher', '$'> }
    token backslash:sym<Z> { 'Z' <.obs: '\\Z as end-of-string matcher', '\\n?$'> }
    token backslash:sym<Q> { 'Q' <.obs: '\\Q as quotemeta', 'quotes or literal variable match'> }
    token backslash:sym<unrec> { {} \w <.panic: 'Unrecognized backslash sequence'> }

    proto token assertion { <...> }

    token assertion:sym<name> {
        <longname=.identifier>
            [
            | <?before '>'> #'>
            | '=' <assertion>
            | ':' <arglist>
            | '(' <arglist> ')'
            | <.normspace> <nibbler>
            ]?
    }
}

class Spit::P5Regex-Actions {
    sub case-star {
        %(
            :bre(''),
            :ere(''),
            :pre(''),
            :case('*'),
        )
    };
    sub maybe-join(@atoms,$re) {
        @atoms.map({ .{$re} // return Nil }).join;
    }
    my sub atom(:$case is copy,:$bre is copy,:$ere is copy,:$all,Match :$match is copy) {
        my $tmp = CALLER::LEXICAL::<$/>;
        $match //= $tmp;
        my Str:D $pre = $match.Str;
        if $all {
            $case = $bre = $ere = True;
        }
        for $bre,$ere,$case {
            $_ = $pre if $_ === True;
        }
        %( :$ere, :$bre, :$case, :$pre );
    }
    method TOP($/) {
        make $<nibbler>.ast;
    }

    method nibbler($/) {
        my Map:D @atoms = $<alternation>.map(|*.ast);
        make {
            bre => @atoms.&maybe-join('bre'),
            ere => @atoms.&maybe-join('ere'),
            case => @atoms.&maybe-join('case'),
            pre => @atoms.map(*.<pre>).join,
        }
    }

    method alternation($/) {
        make $<sequence>.kv.map: -> $i,$_ {
            slip (atom(:all,:match($<sym>[$i-1])) unless $i == 0),|.ast;
        }
    }
    method sequence($/) {
        my Map:D @atoms = $<quantified_atom>.map(|*.ast);
        if @atoms {
            @atoms.unshift(case-star()) unless  @atoms[0]<pre> eq '^'|'*';
            @atoms.push(case-star())  unless @atoms[*-1]<pre> eq '$'|'*';
        }
        make @atoms;

    }

    method quantified_atom($/) {
        make ($<atom>.ast,( $_ with $<quantifier>.ast));
    }

    method atom($/){
        $*prev-atom = do with $<metachar> {
            .ast || atom();
        } else {
            atom(:all);
        }
        make my $tmp = $*prev-atom;
    }
    method p5metachar:sym<quant>($/) { make $<quantifier>.ast }
    method p5metachar:sym<bs>($/){
         $<p5backslash>.ast andthen make($_);
    }

    method p5backslash:sym<d> ($/) {
        make atom bre => '[[:digit:]]',ere => '[[:digit:]]';
    };
    method p5backslash:sym<s>($/) {
        make atom bre => '[[:space:]]',ere => '[[:space:]]';
    }
    my $case_special = <( ) [ ] * ?>;
    method p5backslash:sym<misc> ($/) {
        my $c := $/.Str;
        make atom ere => "\\$c",bre => "\\$c",
             case => $case_special.first($c) ?? "\\$c" !! $c;
    }

    method p5metachar:sym<.>($/) { make atom(bre => '.',ere => '.',case => '?') }
    method p5metachar:sym<^>($/) {
        $*prev-atom andthen .<case> andthen ($_ = '' when '*');
        make atom(:bre,:ere,:case(''));
    }
    method p5metachar:sym<$>($/) { make atom(:bre,:ere,:case('')) }
    method p5metachar:sym<( )>($/) {
        make atom(
            |(ere => ('(' ~ $_ ~ ')') with $<nibbler>.ast<ere>),
            |(bre => ('\\(' ~ $_ ~ '\\)') with $<nibbler>.ast<bre>)
        );
    }
    method p5metachar:sym<[ ]>($/) {
        if $<cclass><sign>.Str eq '^' {
            make atom(:ere,:bre, case => '[!' ~ $<cclass><charspec>.join ~ ']')
        } else {
            make atom(:all) }
        }
    method p5metachar:sym<var>($/) {
        with $<backref> {
            make atom (
                ere => '\\' ~ .Str,
                bre => '\\' ~ .Str,
            )
        }
    }

    method p5quantifier:sym<*>($/) {
        if $*prev-atom<pre> eq '.'
        {
            $*prev-atom<case> = '';
            make atom(:all);
        } else {
            make atom(:ere,:bre);
        }
    }
    method p5quantifier:sym<+>($/) { make atom(:ere) }
    method p5quantifier:sym<?>($/)  { make atom(:ere,:bre) }
    method p5quantifier:sym<{ }>($/) {
        make atom(
            bre => '\\' ~ $/.Str.substr(0,*-1) ~ '\\}',
            ere => $/.Str,
        )
    }

}
