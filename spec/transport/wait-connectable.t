use Test;

plan 3;

constant $port = 4242;

{
    my $before = now;
    Host<8.8.8.8>.wait-connectable($port, :timeout(10) );
    my $diff = (now.posix - $before.posix);
    ok  $diff >= 10 && $diff <= 11,
      'timeout is roughly correct when the connection is being dropped';
}

{
    my $before = now;
    Host.local.wait-connectable($port, :timeout(10));
    my $diff = now.posix - $before.posix;
    ok $diff >= 10 && $diff <= 11,
      'timeout is roughly correct when the connection is being refused';
}

{
    my $tmp = File.tmp.write: "foo";
    my $waiting = start {
        my $before = now;
        Host.local.wait-connectable($port, :timeout(10));
        my $diff = now.posix - $before.posix;
        $diff >= 5 && $diff <= 6;
    }
    sleep 5;
    # start a server that it should connect to
    my $server = start Port($port).serve-file($tmp);
    sleep 1;
    if $waiting.wait {
        pass 'port opened while waiting';
    } else {
        flunk 'port opened while waiting';
    }
    kill $server, $server.descendants;
}
