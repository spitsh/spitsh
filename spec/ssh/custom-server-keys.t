use Test; plan 2;

{
    my $:port = 4242;
    my $server-pair = SSH-keypair.tmp;
    my $client-pair = SSH-keypair.tmp;

    $server-pair.public-key.known-host(Host.local).add;

    SSHd.authorize-key($client-pair.public-key);
    start SSHd.run(:$:port, server-keys => $server-pair);

    sleep 1;

    ok Host.local.wait-connectable($:port, :timeout(1)), '.run started the ssh server';

    my $res = Host.local.ssh(
        :$:port,
        identity => $client-pair.private-key-file,
        # need to force the server to use the public key we added
        host-key-algorithms => $server-pair.keytype,
        eval{ print "success" }
    );

    is $res, "success", 'got a message back from the server';

}
