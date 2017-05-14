use Test;

plan 5;

nok 0,"zero is false";
ok  1,"one is true";

is (1..5).sum, 15, 'List[Int].sum';

ok "1231241"-->Int.valid, '1231241 is valid';
nok "123f241"-->Int.valid, '123f241 is not';
