use Test; plan 7;

my $:port = 4242;
my $server-pair = SSH-keypair.tmp;
my $client-pair = SSH-keypair.tmp;

ok $server-pair, 'keypair exists';

SSHd.set-keypair($server-pair);

ok SSHd.get-keypair($server-pair.type).private-key eq $server-pair.private-key,
'.set-keypair';

SSHd.authorize-key($client-pair.public-key);

$server-pair.public-key.known-host(Host.local).add;

ok $:ssh-known-hosts.contains($server-pair.public-key),
'known_hosts now has the public key';

my $server-pid = start SSHd.run(:$:port);

sleep 1;
ok Host.local.wait-connectable($:port, :timeout(1)), '.run started the ssh server';


my $res = Host.local.ssh-exec(
    :$:port,
    identity => $client-pair.private-key-file,
    # need to force the server to use the public key we added
    host-key-algorithms => $server-pair.keytype,
    eval{ print "success" }
);


is $res, "success", 'got a message back from the server';

CHECK-CLEAN {
    nok $server-pair, '.tmp cleaned up server pair';
    nok $client-pair, '.tmp cleaned up client pair';
}
