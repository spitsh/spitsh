use Test;

plan 6;

ok $?PID ~~ Int, 'PIDs are Ints';
ok $?PID > 0, 'PID is greater than 0';
ok $?PID.exists, '$?PID exists';
ok $?PID, '$?PID in Boolean context return whether it exists';
nok ($?PID * 42 + 42)-->PID, ‘Crazy PID shouln't exist’;

ok "{$?PID}foo".matches(/^\d+foo$/), 'can use $?PID in ""';
