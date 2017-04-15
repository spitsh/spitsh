use Test;

plan 6;

ok $$ ~~ Int, 'PIDs are Ints';
ok $$ > 0, 'PID is greater than 0';
ok $$.exists, '$?PID exists';
ok $$, '$?PID in Boolean context return whether it exists';
nok ($$ * 42 + 42)-->PID, ‘Crazy PID shouln't exist’;

ok "$$foo".matches(/^\d+foo$/), 'can use $$ in ""';
