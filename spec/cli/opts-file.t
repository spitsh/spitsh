use Test; plan 2;

constant $:spit = 'spit';

{
    my $opts = File.tmp.write: {
        one => "foo",
        two => "bar",
        "three:four" => "baz",
    };

    is ${ $:spit eval -f $opts 'say "$:<one>-$:<two>-$:<three:four>"'  | sh },
      'foo-bar-baz', 'basic json opts file'
}

{
    my $opts = File.tmp.write: q‘
        foo : |
          one
          two
          three
        bar : "baz"
    ’;

    is ${ $:spit eval -f $opts 'say "$:<foo>"' | sh }, <one two three>,
      'basic yaml opts file';
}
