use Test;

plan 3;

nok 0,"zero is false";
ok  1,"one is true";

is (1..5).sum, 15, 'List[Int].sum';
