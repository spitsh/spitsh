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
    my @descendants = $pid.descendants;
    ok @descendants == 9, '.descendants';

    # Kill all the descendant processes which should allow the parent to exit
    kill @descendants;
    wait @descendants;
    sleep 1;

    nok $pid, '.Bool is .exists (False) after the parent should have exited';
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

    my @descendants = $pid.descendants;
    kill @descendants;
    wait @descendants;
    sleep 1;
    ok $pid, 'pid still exists after .descendants.kill';
    is $pid.descendants, "", '.descendants is empty after .descendants.kill';
}
