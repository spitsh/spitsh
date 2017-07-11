use Test; plan 5;

{
    my $:foo = "foo";
    is $:foo,'foo',"option set correctly";
}

{
    ok eval(:bar<baz>){ my $:bar = "bar"; say $:bar; }.contains('baz'),
    'setting option seems to have worked';
}

{
    my $:arg = "named";
    sub test-opt(:$arg) {
        is $arg,'named',q<:$:named as an arg>;
    }
    test-opt :$:arg;
}
{
    is eval(fun => "and games"){ print $:<fun> }.${sh}, 'and games',
      'Indirect option lookup where value given';

    is eval(){ print $:<fun> }.${sh}, '',
      'Indirect option lookup with no value';

}
