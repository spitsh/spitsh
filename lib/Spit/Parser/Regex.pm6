need Spit::Parser::Lang;
need Spit::SAST;
need Spit::Exceptions;
# A lot of this copied from NQP p5 regex.
# Lots of p5 regex stuff not parsed properly.
# The purpose of this is to see if we can 'downgrade' the regex
# to a shell pattern or extended grep like regex.


my $metachar-brackets = '{([';

my sub atom(Str :$ere is copy, :$case is copy,:$bre is copy,:$all is copy,Match :$match is copy) {
    my $tmp = CALLER::LEXICAL::<$/>;
    $match //= $tmp;
    $ere = $match.Str unless $ere.defined;
    $all = $ere if $all === True;
    with $all {
        $ere = $case = $bre = $all;
    } else {
        for $case,$bre {
            $_ = $ere if $_ === True;
        }
    }
    %( :$ere, :$bre, :$case );
}

role Spit::Regex::balanced {

    token balanced {
        <?{ $*opener and not $metachar-brackets.contains($*opener) and $*opener ne $*closer }>
        $<opener>=$*opener <nibbler> $<closer>=$*closer
        {
            my $nibbler = $<nibbler>.ast;
            my %patterns;
            my ($o, $c) = (~$<opener>,~$<closer>);
            for $nibbler.kv -> $type, $inner {
                %patterns{$type} = $o ~ $inner ~ $c;
            }
            $/.make: %patterns;
        }
    }
}

grammar Spit::Regex is Spit::Lang {
    token TOP(:$*opener = Nil,:$*closer!) {
        :my @*placeholders;
        <nibbler>
    }

    token rxstopper { $*closer }

    token nibbler {
        <alternation>*
    }
    token alternation {
        <sequence>+ % $<sym>='|'
    }
    token sequence {
        :my $*prev-atom;
        <quantified_atom>+
    }
    token quantified_atom {
        <![|)]>
        <!rxstopper>
        [ <balanced> || <atom> ]
        <quantifier>?
    }
    token balanced { <!> }
    token atom {
        [
            | \w
            | <metachar>
            | {} \W
        ]
    }
    proto token metachar {*}
    token metachar:sym<quant> {
        <![(?]>
        <quantifier>
        <.panic: "quantifier quantifies nothing">
    }
    token metachar:sym<bs> { \\ <backslash> }
    token metachar:sym<.>  { <sym> }
    token metachar:sym<^>  { <sym> }
    token metachar:sym<$>  {
        '$' <?before \W | $>
    }

    token metachar:sym<(?: )> { '(?:' {} <nibbler> ')' }
    token metachar:sym<( )> { '(' {} <nibbler> ')' }
    token metachar:sym<[ ]> { <?before '['> <cclass> }
    token metachar:sigily {
        <?[$]> [$<backref>=\d+]
        ||
        <spit-sigily>
    }

    token cclass {
        :my $astfirst = 0;
        '['
        $<sign>='^'?
        [
        || $<charspec>=(
               ( '\\' <backslash> || (<?{ $astfirst == 0 }> <-[\\]> || <-[\]\\]>) )
               [
                   \s* '-' \s*
                   ( '\\' <backslash> || (<-[\]\\]>) )
               ]**0..1
               { $astfirst++ }
           )+
           ']'
        || <.panic: "failed to parse character class; unescaped ']'?">
        ]
    }

    proto token backslash { <...> }

    token backslash:sym<A> { <sym> }
    token backslash:sym<b> { $<sym>=[<[bB]>] }
    token backslash:sym<r> { <sym> }
    token backslash:sym<R> { <sym> }
    token backslash:sym<s> { $<sym>=[<[dDnNsSwW]>] }
    token backslash:sym<t> { <sym> }
    token backslash:sym<x> {
        <sym>
        [
        |           $<hexint>=[ <[ 0..9 a..f A..F ]>**0..2 ]
        | '{' ~ '}' $<hexint>=[ <[ 0..9 a..f A..F ]>* ]
        ]
    }
    token backslash:sym<z> { <sym> }
    token backslash:sym<Z> { <sym> }

    token backslash:sym<misc> { $<litchar>=(\W) | $<number>=(\d+) }
    token backslash:sym<oops> { <.panic: "Unrecognized Perl 5 regex backslash sequence"> }

    token p5mod  { <[imsox]>* }
    token p5mods { <on=p5mod> [ '-' <off=p5mod> ]**0..1 }

    proto token quantifier { <...> }
    token quantifier:sym<*>  { <sym> <quantmod> }
    token quantifier:sym<+>  { <sym> <quantmod> }
    token quantifier:sym<?>  { <sym> <quantmod> }
    token quantifier:sym<{ }> {
        '{'
        $<start>=[\d+]
        [ $<comma>=',' $<end>=[\d*] ]**0..1
        '}' <quantmod>
    }

    token quantmod { [ '?' | '+' ]? }

    method get-tweak($_) {
        when 'balanced' { Spit::Regex::balanced }
    }
}

class Spit::Regex-Actions {
    sub case-star {
        %(
            :bre(''),
            :ere(''),
            :case('*'),
        )
    };

    method TOP ($/) {
        my $patterns =  $<nibbler>.ast;
        make SAST::Regex.new( :$patterns, :@*placeholders );
    }

    method nibbler($/) {
        sub maybe-join(@atoms,$re) {
            @atoms.map({ .{$re} // return Nil }).join;
        }

        my Map:D @atoms = $<alternation>.map(|*.ast);

        my %patterns = do for <ere bre case> -> $type {
            |($type => $_ with @atoms.&maybe-join($type) )
        };

        make %patterns;
    }

    method alternation($/) {
        make $<sequence>.kv.map: -> $i,$_ {
            slip (atom(:all,:match($<sym>[$i-1])) unless $i == 0),|.ast;
        }
    }

    method sequence($/) {
        my Map:D @atoms = $<quantified_atom>.map(|*.ast);
        if @atoms {
            @atoms.unshift(case-star()) unless  @atoms[0]<ere> eq '^';
            @atoms.push(case-star())  unless @atoms[*-1]<ere> eq '$'|'*';
        }
        make @atoms;

    }

    method quantified_atom($/) {
        make ($<atom>.ast // $<balanced>.ast,( $_ with $<quantifier>.ast));
    }

    method atom($/){
        $*prev-atom = do with $<metachar> {
            my $metachar = .ast;
            unless $metachar and $metachar<ere> {
                SX::NYI.new(feature => "Regex metachar ‘{$<metachar>.Str}’").throw;
            }
            $metachar;
        } else {
            atom(:all);
        }
        make my $tmp = $*prev-atom;
    }

    method metachar:sym<quant>($/) { make $<quantifier>.ast }

    method metachar:sym<bs>($/){
         $<backslash>.ast andthen make($_);
    }

    method backslash:sym<s>($/) {
        my $char = $<sym>.Str;
        my $cc = do given $char.lc {
            when 'd' { '[0-9]' }
            when 's' { '[[:space:]]' }
            default  { "\\$char" } # just hope it works atm
        }
        if $char.uc eq $char {
            $cc .= subst('[','[^');
        }
        make atom ere => $cc;
    }
    my $case_special = <( ) [ ] * ?>;
    method backslash:sym<misc> ($/) {
        my $c := $/.Str;
        make atom ere => "\\$c",bre => "\\$c",
             case => $case_special.first($c) ?? "\\$c" !! $c;
    }

    method metachar:sym<.>($/) { make atom(bre => '.',ere => '.',case => '?') }

    method metachar:sym<^>($/) {
        make atom(:bre,:case(''));
    }

    method metachar:sym<$>($/) { make atom(:bre,:case('')) }

    method metachar:sym<( )>($/) {
        make atom(
            |(ere => ('(' ~ $_ ~ ')') with $<nibbler>.ast<ere>),
            |(bre => ('\\(' ~ $_ ~ '\\)') with $<nibbler>.ast<bre>)
        );
    }
    method metachar:sym<[ ]>($/) {
        if $<cclass><sign>.Str eq '^' {
            make atom(:bre, case => '[!' ~ $<cclass><charspec>.join ~ ']')
        } else {
            make atom(:all)
        }
    }

    method metachar:sigily ($/) {
        with $<backref> {
            make atom (
                ere => '\\' ~ .Str,
                bre => '\\' ~ .Str,
            )
        } else {
            my @placeholders := @*placeholders;
            my $placeholder   = '{{' ~ +@placeholders ~ '}}';
            @placeholders.push: $<spit-sigily>.ast;
            make atom(:all($placeholder));
        }
    }

    method quantifier:sym<*>($/) {
        if $*prev-atom<ere> eq '.' {
            $*prev-atom<case> = '';
            make atom(:all);
        } else {
            make atom(:bre);
        }
    }
    method quantifier:sym<+>($/) { make atom() }
    method quantifier:sym<?>($/)  { make atom(:bre) }
    method quantifier:sym<{ }>($/) {
        make atom(
            bre => '\\' ~ $/.Str.substr(0,*-1) ~ '\\}',
            ere => $/.Str,
        )
    }
}
