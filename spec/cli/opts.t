use Test; plan 1;

constant $:spit = 'spit';


{
    is ${ $:spit eval '${printf "hello world" >X}' -o 'NULL=$:OUT'}.${sh !>~},
      'hello world', ‘-o NULL=$:OUT’;
}
