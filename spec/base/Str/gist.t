use Test; plan 4;

{
    my $a = "foo";
    my $b = "";
    is $a.gist, 'foo','"foo".gist';
    is $b.gist, '','"".gist';

    is $a.Bool.gist, 'True', '"foo".Bool.gist';
    is $b.Bool.gist, 'False', '"".Bool.gist';
}
