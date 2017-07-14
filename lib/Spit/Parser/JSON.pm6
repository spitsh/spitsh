need Spit::SAST;
need JSON::Tiny::Grammar;
need JSON::Tiny::Actions;
need Spit::Parser::Lang;

grammar Spit::JSON::Grammar is JSON::Tiny::Grammar is Spit::Lang {}

class Spit::JSON::Actions is JSON::Tiny::Actions {

    method value:sym<number> ($/){
        make SAST::IVal.new(val => $/.Str.Int);
    }

    method value:sym<string> ($/){
        make SAST::SVal.new(val => $<string>.made);
    }

    method value:sym<true>($/)   { make SAST::BVal.new(val => True)  }
    method value:sym<false>($/)  { make SAST::BVal.new(val => False) }
    method value:sym<null>($/)   { make SAST::SVal.new(val => "") }
    method value:sym<object>($/) {
        make SAST::JSON.new(
            src => SAST::SVal.new(val => $/.Str),
            data => $<object>.made,
        );
    }

    method value:sym<array>($/) {
        make SAST::JSON.new(
            src => SAST::SVal.new(val => $/.Str),
            data => $<array>.made,
        );
    }

}

# method value:string ($match) {
#     my $str =  ~$match<string>.made;
#     if $str ~~  s/^':'// {
#         $match.make: Spit::LateParse.new(val => $str,:$match);
#     } else {
#         $str ~~ s/^'\:'/':'/;
#         $match.make: SAST::SVal.new(val => $str,:$match);
#     }
# }


# vim: ft=perl6
