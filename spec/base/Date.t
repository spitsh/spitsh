use Test;

plan 8;

ok Date.year.starts-with('20'),  '.year starts with 20';
ok Date.month ~~ /^(1[0-2]|[1-9])$/, '.month';
ok Date.day ~~ /^([1-9]|[12]\d|3[01])$/, '.day (of month)';
ok Date.dow ~~ /^[0-6]$/, '.dow';
ok Date.hour ~~ /^(1?[0-9]|2[0-3])$/, '.hour';
ok Date.minute ~~ /^([1-5]?[0-9])$/, '.minute';
ok Date.second ~~ /^([1-5]?[0-9])$/, '.second';
ok Date.epoch ~~ /^\d+$/, '.epoch';
