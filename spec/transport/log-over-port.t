use Test; plan 2;

{
    my $port = 3003;
    my $logfile = File.tmp;
    eval(:log, :$logfile){
        my File $:logfile;
        $:LOG = $:logfile.open-w;
        my $pid = start Port($port).tail-file($:logfile);
        info 'first log';
        sleep 1;
        info 'second log';
        start { sleep 3; kill $pid, $pid.descendants; };
    }.${sh};

    sleep 1;

    my Log @logs = Host.local.read-port($port);

    is @logs[0].message, 'first log', 'first log';
    is @logs[1].message, 'second log', 'second log';

}
