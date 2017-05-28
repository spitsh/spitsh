use Test;

plan 15;

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

    ok $pid, '.Bool is .exists (True)';
    ok $pid.children == 3, '.children';
    ok $pid.descendants == 9, '.descendants';

    # If you don't kill $pid as well you get zombies
    kill $pid, $pid.descendants;

    sleep 1;
    nok $pid, '.Bool is .exists (False)';
    ok $pid.children    == 0, '.children after killing';
    ok $pid.descendants == 0, '.descendants after killing';
}

{
    is eval{ kill }.${sh *>~}, '', 'no error message when called with no arguments';
}

{
    my $pid =
    start {
        start {
            start {
                sleep 100; ${true}
            };
            sleep 100; ${true}
        };
        # exec at the end because dash/BB sh do this anyway but bash doesn't
        sleep 100;
        ${exec sleep 100};
    };

    $pid.descendants.kill;
    sleep 1;
    ok $pid, 'pid still exists after .descendants.kill';
    nok $pid.descendants, '.descendants is false after .descendants.kill';
}
