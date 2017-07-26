use Test; plan 2;

constant $:spit = 'spit';


{
    is ${ $:spit eval '${printf "hello world" >X}' -o 'NULL=$:OUT'}.${sh !>~},
      'hello world', ‘-o NULL=$:OUT’;
}

{
    ok ${ $:spit eval
          -o 'log-level:2' -o 'log' --os $:os.name
         'info "foo"; debug "bar"'
        }.${sh !>~}.ends-with("foo"),
    '-o log-level:2';
}
