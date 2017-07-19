use Test; plan 4;

constant $:spit = 'spit';
{
    is ${ $:spit eval 'END { say "win" }; die "foo";' --RUN !>X }, 'win',
      'END runs after die';

    nok ${ $:spit eval 'END { say "win" }; die "foo";' --RUN !>X },
      'bad exit status after die';

    is ${ $:spit eval 'END { say "win" };' --RUN !>X }, 'win',
      'END runs with a clean exit';

    ok ${ $:spit eval 'say "hello world"' --RUN >X },
      'good exit status without a die';
}
