use Test;

plan 8;

my $pid = start sleep 1000;
ok $pid,'pid exists after starting it';
kill $pid;
wait $pid;
nok $pid, 'pid is gone after killing it';

is eval{
    start {
        say "one";
        sleep 2;
        say "three";
    }
    sleep 1;
    say "two";
}.${sh}, <one two three>, 'sleep in start block seems to stagger';


is eval{
    my $pid = start {
        say "one";
        sleep 2;
        say "three";
    }
    sleep 1;
    $pid.kill;
    say "two";
}.${sh}, <one two>, ‘.kill on start's pid cancels it’;


is eval{
    my $pid = start {
        say "one";
        sleep 2;
        say "three";
    }
    sleep 1;
    $pid.wait;
    say "two";
}.${sh}, <one three two>, ‘.wait on the PID waits untill it's finished’;

is eval{
    my $pid1 = start {
        sleep 1;
        say 2;
        sleep 2;
        say 4;
    }

    my $pid2 = start {
        sleep 2;
        say 3;
        sleep 2;
        say 5;
    }

    say 1;
    wait $pid1, $pid2;
    say 6;
}.${sh}, <1 2 3 4 5 6>, ‘List[PID].wait’;

{
    my $pid = File.tmp;
    sub foo()~ {
        $pid.write: start sleep 1000;
        "foo";
    }

    is foo(), 'foo', 'can return from a sub that starts a process';
    ok $pid.slurp-->PID.kill, 'kill process created in sub';
}
