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
                    # ${true} are just here to be NOPs to force dash
                    # busybox not to optimize away 'sh' processes by
                    # exec(3)ing into the last command.
                    ${true};
                }
                sleep 200;
                ${true};
            }
            sleep 300;
            ${true};
        }
        start {
            sleep 400;
            ${true};
        }
        sleep 500;
        ${true};
    }

    ok $pid.children == 3, '.children';
    ok $pid.descendants == 9, '.descendants';

    # If you don't kill $pid as well you get zombies
    kill "TERM", $pid, $pid.descendants;

    ok $pid.children    == 0, '.children after killing';
    ok $pid.descendants == 0, '.descendants after killing';
}

{
    is eval{ kill 'TERM' }.${sh *>~}, '', 'no error message when called with no arguments';
}
