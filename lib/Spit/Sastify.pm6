# subs to turn p6 values into equivalent SAST values
use Spit::SAST;
use Spit::Util :light-load;
use Spit::Exceptions;
need Spit::Metamodel;
need Spit::Constants;

constant $null = ("" ~~ /<?>/);

sub sastify($_, :$match = $null) is export {
    when Spit::Type  { SAST::Type.new(class-type => $_,:$match) }
    when Int         { SAST::IVal.new(val => $_,:$match) }
    when Str         { SAST::SVal.new(val => $_,:$match) }
    when Bool        { SAST::BVal.new(val => $_,:$match) }
    default          { Nil }
}

# Takes a string and gives back the associated OS as a SAST::Type
sub sast-os(Str:D $name, :$match = $null) is export {
    my $SETTING = once light-load 'Spit::PRECOMP', export-target => '$SETTING';
    my $OS  = once $SETTING.lookup(CLASS, 'OS').class;
    if $OS.^lookup-by-str($name) -> $os {
        SAST::Type.new(class-type => $os, :$match);
    } else {
        Nil;
    }
}


class Spit::LateParse is rw {
    has Str:D $.val is required;
    has Match:D $.match is required;

    method gist { "Spit::LateParse($.val)" }
}

sub late-parse($val, :$match = $null) is export {
    Spit::LateParse.new(:$match, :$val);
}
