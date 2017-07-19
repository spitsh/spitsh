use Test; plan 2;


{
    is eval(fun => "and games"){ print $:<fun> }.${sh}, 'and games',
    'Indirect option lookup where value given';

    is eval(){ print $:<fun> }.${sh}, '',
    'Indirect option lookup with no value';
}
