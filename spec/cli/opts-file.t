use Test; plan 1;

constant $:spit = 'spit';
{
    my $opts = File.tmp.write: {
        one => "foo",
        two => "bar",
        three => "baz",
    };

    is ${ $:spit eval -f $opts 'say "$:<one>-$:<two>-$:<three>"'  | sh },
      'foo-bar-baz';
}
