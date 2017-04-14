use Spit::SAST;
need Spit::Parser::Lang;
need Spit::Exceptions;

role Spit::Quote::curlies {
    token elem:curlies {
        <?before '{'> $<block>=<.LANG('MAIN','block')>
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

role Spit::Quote::align-indent {

    token elem:line-start {
        <?after \n>
        [
            || <!{$*align-indent.defined}>
                (\h*)
                { $*align-indent = $/[0].Str.chars }
            ||
            <?{ $*align-indent > 0}>
            \h ** { 1..$*align-indent }
        ]
        { $/.make('') }
    }
}

grammar Spit::Quote is Spit::Lang {
    token TOP(:$*opener = Nil,:$*closer!) {
        :my $*align-indent;
        <quoted>
    }

    token quoted {
        [ $<bit>=<.elem> || <!before $*opener|$*closer>$<bit>=[\w+||.] ]*
    }

    proto token elem {*};

    method get-tweak($_){
        when 'curlies' { Spit::Quote::curlies }
        when 'balanced' { Spit::Quote::balanced }
        when 'align-indent' { Spit::Quote::align-indent }
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
}

class Spit::Quote::q-Actions is Spit::Quote::Actions {
    method elem:escaped ($/){
        make ($<escaped><special> andthen .Str) || $/.Str;
    }
}

grammar Spit::Quote::qq is Spit::Quote {

    proto token backslash {*};
    token backslash:sym<n> { <.sym> }
    token backslash:sym<c> { 'c['$<unicode-name>=[ <!before ']'> . ]*']' }
    token backslash:literal { \W }
    token elem:escaped {
        '\\' [<backslash> || <.panic(qq|backslash escape sequence|)>]
    }
    token elem:sigily { <spit-sigily> }
}

class Spit::Quote::qq-Actions is Spit::Quote::Actions {
    method backslash:sym<n>($/) { make "\n" }
    method backslash:sym<c>($/) {
        make parse-names((my $match = $<unicode-name>).Str) ||
            SX.new(message => "Unrecognised unicode name '{$match.Str}'",:$match).throw;
    }
    method backslash:literal ($/) { make $/.Str }
    method elem:escaped ($/) { make $<backslash>.ast }
    method elem:sigily ($/)  { make $<spit-sigily>.ast }
}
