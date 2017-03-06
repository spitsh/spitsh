#| Any is the root of the class.  It's like [Perl 6's
#| Mu](https://docs.perl6.org/type/Mu), (confusingly [Str](Str.md) is
#| more like [Perl 6's Any](https://docs.perl6.org/type/Any)). Any has
#| no methods yet. The main role it plays is to be Spit's "void"
#| context:
#|{
    my $a = "foo";
    my $b = "bar";
    True ?? $a !! $b; # $a and $b are in Any context
    say True ?? $a !! $b; # $a and $b are in Str context
}
augment Any {}
