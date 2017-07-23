use Test; plan 2;
{
    my $keypair = SSH-keypair.tmp;
    my $before = $keypair.public-key.key;

    $keypair.public-key-file.remove;
    $keypair.generate-public-key;

    ok $before, ‘public-key isn't empty’;
    is $keypair.public-key.key, $before,
      '.generate-public-key generated the right public key';
}
