# Dumping group for tests that mess up inlining
use Test;

plan 1;

sub foo($a)~{ $:NULL.write("goof"); "wtf" };
sub bar~{ foo File.tmp(:dir).add("woot") };

nok bar() eq "woot", "inner method chain didn't disappear";
