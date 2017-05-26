use Test;

plan 11;

ok $?PID ~~ Int, 'PIDs are Ints';
ok $?PID > 0, 'PID is greater than 0';
ok $?PID.exists, '$?PID exists';
ok $?PID, '$?PID in Boolean context return whether it exists';
nok ($?PID * 42 + 42)-->PID, ‘Crazy PID shouln't exist’;

ok "{$?PID}foo".matches(/^\d+foo$/), 'can use $?PID in ""';

{
    my $pid = start {
        start {
            start {
                start {
                    sleep 100;
                }
                sleep 200;
            }
            sleep 300;
        }
        start { sleep 400 }
        sleep 500;
    }

    ok $pid.children == 2, '.children';
    ok $pid.descendants == 4, '.descendants';

    # If you don't kill $pid as well you get zombies
    kill "TERM", $pid, $pid.descendants;

    ok $pid.children    == 0, '.children after killing';
    ok $pid.descendants == 0, '.descendants after killing';
}

{
    is eval{ kill 'TERM' }.${sh *>~}, '', 'no error message when called with no arguments';
}
