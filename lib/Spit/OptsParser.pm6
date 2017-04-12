need JSON5::Tiny::Grammar;
need JSON5::Tiny::Actions;
use JSON5::Tiny;

need Spit::SAST;

# for wrapping an expressiona for evaluation in stage3
class Spit::LateParse is rw {
    has $.name;
    has Str $.val;
    has $.match;

    method gist { "Spit::LateParse($.name => $.val)" }
}

my $actions = my class Spit::OptsParser::Actions is JSON5::Tiny::Actions {
    method value:int ($/) { make SAST::IVal.new(val => +$/.Int); }
    method value:num ($/) { die "$/ NYI" }
    method value:exp ($/) { die "$/ NYI" }
    method value:inf ($/) { die "$/ NYI" }
    method value:hex ($/) { die "$/ NYI" }
    method value:string ($match) {
        my $str =  ~$match<string>.made;
        if $str ~~  s/^'$:'// {
            $match.make: Spit::LateParse.new(val => $str,:$match);
        } else {
            $match.make: SAST::SVal.new(val => $str,:$match);
        }
    }
    method value:sym<true> ($/)   { make SAST::BVal.new(val => True )  }
    method value:sym<false> ($/)  { make SAST::BVal.new(val => False) }
    method value:sym<null> ($/)   { make SAST::SVal.new(val => "") }
    method pair ($/){
        my $value = $<value>.ast;
        if $value ~~ Spit::LateParse {
            $value.name = 'option(' ~ $<key>.ast ~ ')';
        }
        callsame;
    }
}

sub parse-opts($json is copy,:%mangle) is export  {
    if %mangle {
        my $d = from-json($json || '{}');
        $d.append(%mangle);
        $json = to-json($d);
    }

    return {} unless $json;
    my $res = JSON5::Tiny::Grammar.parse($json,:$actions) || die "opts not valid json";
    return $res.made;
}
