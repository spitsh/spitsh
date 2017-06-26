use Test; plan 3;
{
    my $cmd = Cmd<nOrtExist> || Cmd<AlsOnotzist> || Cmd<printf>;
    is $cmd,'printf','Cmd or junction returns the one that exists';
}

{

    ok Cmd<ls>.path.matches(rx{(/usr)?/bin/ls}), 'Cmd<ls>.path';
    ok Cmd<grep>.path.matches(rx{(/usr)?/bin/grep}), 'Cmd<grep>.path';
}
