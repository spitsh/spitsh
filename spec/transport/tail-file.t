use Test;

plan 8;

given Port.random {
    my $in = File.tmp;
    my $out = File.tmp;
    my $tail-pid = start .tail-file($in);
    sleep 1;
    my $client-pid = start Host.local.read-port($_).append-to($out);
    sleep 1;
    is .listening, $tail-pid,
      ".listening PID is the one we started ($tail-pid)";

    ok Host.local.connectable($_, :timeout(1)),
      '.connectable';
    $in.append("first line\n");
    sleep 1;
    is $out.slurp, 'first line', 'first line was written';
    $in.append("second line\n");
    sleep 1;
    is $out.slurp, "first line\nsecond line",
      'second line was written';
    $in.append("third line\n");
    sleep 1;
    is $out.slurp, "first line\nsecond line\nthird line",
      'third line was written';

    kill $tail-pid, $tail-pid.descendants;
    sleep 1;
    nok .listening, '.listening after .kill';
    nok Host.local.connectable($_, :timeout(1)),
    '.connectable after .kill';
    nok $client-pid, 'client pid has stopped after server has stopped';
}
