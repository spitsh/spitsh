use Test;

plan 4;

    #|{
    foo
    }
class one {}

#|{ bar }
class two {}

   #|{
   if True {
       foo
   }
   }
class three {}

#|{
my $outdated = 'foo1.myorg.com';
if File</etc/foo.conf>.contains($outdated) {
    note "$outdated exists in $_...fixing!";
    .copy-to('/etc/foo.conf.bak');
    .subst($outated,'foo2.myorg.com');
}
}
class four{}

ok one.WHY.contains("\nfoo"),'heredoc indenting alignment';
ok two.WHY.ends-with('bar'),'ws removed from the end of #|{}';
ok three.WHY.starts-with(qq{\nif True {\n    foo\n}}),'curlies inside block';
ok four.WHY.contains("\{\n    note"),'non indented finishing curly';
