use Test; plan 4;

my $:port = 4242;

# for the server
my $ed25519 = SSH-keypair.tmp(type => 'ed25519');
my $ecdsa   = SSH-keypair.tmp(type => 'ecdsa' );

my $client-pair = SSH-keypair.tmp;

# remove other types of keys from the server so we get presented
# with one of the above
SSHd.get-keypair('rsa').remove;


SSHd.authorize-key($client-pair.public-key);

for $ed25519, $ecdsa { SSHd.set-keypair($_) }

my $server-pid = start SSHd.run(:$:port);

sleep 1;

ok Host.local.wait-connectable($:port, :timeout(1)), '.run started the ssh server';

Host.local.ssh-keyscan(:$:port).add;


ok $:ssh-known-hosts.contains($ed25519.public-key.key),
  '.ssh-keyscan.add added ed25519 key';

ok $:ssh-known-hosts.contains($ecdsa.public-key.key),
  '.ssh-keyscan.add added ecdsa key';

my $res = Host.local.ssh-exec(
    :$:port,
    identity => $client-pair.private-key-file,
    # need to force the server to use one of the public key we added
    host-key-algorithms => $ed25519.keytype,
    eval{ print "success" }
);


is $res, "success", 'got a message back from the server';
