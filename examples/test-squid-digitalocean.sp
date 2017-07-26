use DigitalOcean;
use file<examples/lib/squid.sp>;

constant $test-host = HTTP<http://httpbin.org>;
constant $:droplet-os = Debian;

DO.ensure-key($:ssh-keypair.public-key, name => 'squid-demo');

my $droplet-save = File.tmp;
my PID @pids;

for <squid-demo squid-client-1 squid-client-2> -> $name {
    my $pid = start {
        my $droplet = DO.create-ssh-seeded(:$name);
        $droplet-save.push: $droplet;
    };

    @pids.push: $pid;

}

wait @pids;

my @droplets = $droplet-save.slurp-->List[Droplet];

my $squid-ip = @droplets[0].ipv4;

start @droplets[0].ssh-seed: eval(os => $:droplet-os, allowed => @droplets[1].ipv4){
    $Squid:pkg.ensure-install;
    Squid.write-conf(allowed-src => $:<allowed>);
    Squid.service.restart;
    info "tailing log";
    ${ tail -f ($Squid:access-log) }.log(2,"\c[SQUID]:access");
};

my $test1 = start {
    ok @droplets[1].ssh-seed( eval(os => $:droplet-os, :$squid-ip ){
        my Host $:squid-ip;

        my $proxy = "{$:squid-ip}:{$Squid:port}";
        ok $:squid-ip.wait-connectable($Squid:port, :timeout(80)), "can connect on $Squid:port";

        ok $test-host.request('GET', :$proxy).is-success,
        'made a request through squid';

        ok $test-host.https.request('GET', :$proxy).is-success,
        'made https request through squid';

        is HTTP<ifconfig.co>.request('GET', :$proxy).body, $:squid-ip, ‘ifconfig.co returns squid's ip’;

        print "ok";
    }),
    'All tests from allowed droplet passed';
};


my $test2 = start {
    ok @droplets[2].ssh-seed( eval(os => $:droplet-os, :$squid-ip ){
        my Host $:squid-ip;
        my $proxy = "$:squid-ip:{$Squid:port}";
        ok $:squid-ip.wait-connectable($Squid:port, :timeout(80)), "can connect on $Squid:port";

        nok $test-host.request('GET', :$proxy).is-success,
        ‘couldn't make a http request through squid’;

        nok $test-host.https.request('GET', :$proxy).is-success,
        ‘couldn't make a https request through squid’;

        print "ok";
    }),
    'All tests from blocked droplet passed';

};

wait($test1, $test2);


END { .delete for @droplets }
