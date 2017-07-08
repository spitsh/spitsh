use Test;
plan 4;

{
    my $img1 = Docker.create('alpine').commit( name => 'foo:bar' ).cleanup;
    my $img2 = Docker.create('alpine').commit( name => 'foo:baz' ).cleanup;

    $img1.add-tag('some-alias:some-tag');
    $img1.add-tag('some-other-tag');

    ok $img1.tags == 3, 'image has 3 tags';

    for <foo:bar some-alias:some-tag foo:some-other-tag> {
        ok $img1.tags.first($_), "has $_";
    }

}
