use Spit::SAST;
need Spit::Parser::Lang;
need Spit::Exceptions;

role Spit::Quote::curlies {
    token elem:curlies {
        {} <?before '{'>  $<block>=<.LANG('MAIN','blockish')>
        {
            my $block := $<block>.ast;
            if $block.children == 0 {
                $/.make: SAST::SVal.new(val => '');
            } else {
                $/.make: $block;
            }
        }
    }
}

role Spit::Quote::balanced {

    token elem:balanced {
        <?{ $*opener and $*opener ne $*closer }>
        $<opener>=$*opener <quoted> $<closer>=$*closer
        { $/.make: ($<opener>.Str,|$<quoted>.ast,$<closer>.Str) }
    }
}

role Spit::Quote::sheardoc {

    token TOP(:$*opener = Nil, :$*closer!) {
        :my $*sheardoc;
        [
            ||"\n"
               #TODO: Investigate how slow this is
            || { $*sheardoc =  $/.pos - $/.orig.substr(0,$/.pos).rindex("\n") - 1 }
        ]
        <quoted>
        { make $<quoted>.ast }
    }

    token elem:line-start {
        <?after \n>
        [
            || <!{$*sheardoc.defined}>
                (\h*)
                { $*sheardoc = $/[0].Str.chars }
            ||
            <?{ $*sheardoc > 0}>
            \h ** { 1..$*sheardoc }
        ]
        { $/.make('') }
    }
}

grammar Spit::Quote is Spit::Lang {
    token TOP(:$*opener = Nil,:$*closer!) {
        <quoted>
    }

    token quoted {
        [ $<bit>=<.elem> || <!before $*opener|$*closer>$<bit>=[\w+||.] ]*
    }

    proto token elem {*};

    method get-tweak($_){
        when 'curlies' { Spit::Quote::curlies }
        when 'balanced' { Spit::Quote::balanced }
        when 'shear' { Spit::Quote::sheardoc }
    }
}

class Spit::Quote::Actions {

    method TOP($/) {
        make $<quoted>.ast;
    }

    method quoted($/) {
        my @string;
        my @sast;
        my @bits = flat $<bit>.map: { .ast // .Str };
        for @bits {
            when Str  { @string.push(.Str) }
            when SAST {
                @sast.push(SAST::SVal.new(val => @string.join)) if @string;
                @string = Empty;
                @sast.push($_);
            }
            default {
                die "quoting gone bad";
            }
        }
        @sast.push(SAST::SVal.new(val => @string.join)) if @string;
        @sast.push(SAST::SVal.new(val => '')) unless @sast;

        make @sast == 1 ?? @sast[0] !! SAST::Concat.new(|@sast);
    }
}


grammar Spit::Quote::q is Spit::Quote {
    token elem:escaped {
        '\\'$<escaped>=($<special>=[$*opener|$*closer|'\\'] || .)
    }
    token elem:sym<§> { <.sym> }
}

class Spit::Quote::q-Actions is Spit::Quote::Actions {
    method elem:escaped ($/){
        make ($<escaped><special> andthen .Str) || $/.Str;
    }

    method elem:sym<§> ($/) {
        make SAST::Var.new(name => ':sed-delimiter', sigil => '$');
    }
}

grammar Spit::Quote::qq is Spit::Quote {

    proto token backslash {*};
    token backslash:sym<a> { <.sym> }
    token backslash:sym<b> { <.sym> }
    token backslash:sym<c> { 'c['$<unicode-name>=[ <!before ']'> . ]*']' }
    token backslash:sym<f> { <.sym> }
    token backslash:sym<n> { <.sym> }
    token backslash:sym<r> { <.sym> }
    token backslash:sym<t> { <.sym> }
    token backslash:sym<x> { 'x' '[' ~ ']' [[$<hex>=<[0..9a..fA..F]> ** {1..6}]+ % ','] }
    token backslash:literal { \W }
    token elem:escaped {
        '\\' [<backslash> || <.panic(qq|backslash escape sequence|)>]
    }
    token elem:sym<§> { <.sym> }
    token elem:sigily { <spit-sigily> }
}

class Spit::Quote::qq-Actions is Spit::Quote::Actions {
    method backslash:sym<a>($/) { make "\a" }
    method backslash:sym<b>($/) { make "\b" }
    method backslash:sym<c>($/) {
        my $str = uniparse((my $match = $<unicode-name>).Str) ||
            SX.new(message => "Unrecognised unicode name '{$match.Str}'",:$match).throw;
        my @chars = $str.comb;
        make $@chars.map({ $_ ~= " " if .uniprops eq 'So'; $_ }).join;
    }
    method backslash:sym<f>($/) { make "\f" }
    method backslash:sym<n>($/) { make "\n" }
    method backslash:sym<t>($/) { make "\t" }
    method backslash:sym<r>($/) { make "\r" }
    method backslash:sym<x> ($/) { make ($<hex>.map({ "0x$_".chr}).join) }
    method backslash:literal ($/) { make $/.Str }
    method elem:escaped ($/) { make $<backslash>.ast }
    method elem:sym<§> ($/) {
        make SAST::Var.new(name => ':sed-delimiter', sigil => '$');
    }
    method elem:sigily ($/)  { make $<spit-sigily>.ast }
}
