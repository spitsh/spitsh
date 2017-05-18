use Test; plan 6;
{
    my $to-archive = File.tmp(:dir);
    $to-archive.add('foo.txt').touch;

    {
        File.tmp(:dir).cd;
        my $archive = $to-archive.archive;
        ok $archive, '.archive exists';
        my $extracted = $archive.extract;
        ok $extracted.d, 'extracted archive is a directory';
        ok $extracted.add('foo.txt'), 'foo.txt exists';
    }

    {
        File.tmp(:dir).cd;
        my $named-archive = $to-archive.archive(to => 'mytar.tgz');
        ok $named-archive, 'to => .archive exists';
        my $extracted = $named-archive.extract;
        ok $extracted.d, 'to => extracted archive is a directory';
        ok $extracted.add('foo.txt'), 'to => foo.txt exists';
    }
}
