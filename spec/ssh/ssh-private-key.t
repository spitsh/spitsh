use Test; plan 1;

my $:port = 4242;

my $client-pair = SSH-keypair.tmp;

SSHd.authorize-key($client-pair.public-key);

my $private-key = $client-pair.private-key;
 $client-pair.remove;

SSHd.generate-missing-keys;

my $server-pid = start SSHd.run(:$:port);

sleep 1;

Host.local.ssh-keyscan(:$:port).add;

eval(ssh-private-key => $private-key){
    my $res = Host.local.ssh(
        :$:port,
        eval{ print "success" },
    );

    is $res, 'success', 'setting $:ssh-private-key is enough to make everything work';
}.${sh};
