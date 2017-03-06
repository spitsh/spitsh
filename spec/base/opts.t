use Test;

plan 3;
{
    my $*foo = "foo";
    is $*foo,'foo',"option set correctly";
}

{
    ok eval(:bar<baz>){ my $*bar = "bar"; say $*bar; }.contains('baz'),
    'setting option seems to have worked';
}

{
    my $*arg = "named";
    sub test-opt(:$arg) {
        is $arg,'named',q<:$*named as an arg>;
    }
    test-opt :$*arg;
}
