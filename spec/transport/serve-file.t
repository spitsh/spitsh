use Test;

plan 9;

my $file = File.tmp;
$file.write: "Hello world";

given Port.random {
    nok .listening, 'nothing .listening on new port';
    nok Host.local.connectable($_, :timeout(1)), 'new port not connectable';

    my $pid = start .serve-file($file);
    sleep 1;
    ok .listening, '.serve-file - something is listening';
    is .listening, $pid, 'listening PID is the one we started';

    ok Host.local.connectable($_), 'localhost is connectable';

    is Host.local.read-port($_), "Hello world",
    'Host.local.read-port returns the file being served #1';

    is Host.local.read-port($_), "Hello world",
    'Host.local.read-port returns the file being served #2';

    $pid.kill;

    nok .listening, '.listening after .kill';
    nok Host.local.connectable($_, :timeout(1)),
      '.connectable after .kill';
}
