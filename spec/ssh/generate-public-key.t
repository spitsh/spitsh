use Test; plan 1;
{
    my $keypair = SSH-keypair.tmp;
    my $before = $keypair.public-key.fingerprint;
    $keypair.public-key-file.remove;
    $keypair.generate-public-key;
    is $keypair.public-key.fingerprint, $before,
      '.generate-public-key generated the right public key';
}

{

}
