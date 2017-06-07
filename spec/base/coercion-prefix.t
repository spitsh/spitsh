use Test;

plan 2;

my File $file = 'NotExisting.txt';

ok ~$file, '~ forces thing to use Str.Bool';

my PID $pid = 213413431;

ok +$pid, '+ forces thing to use Int.Bool';
