use Test; plan 3;
{
    my $cmd = Cmd<nOrtExist> || Cmd<AlsOnotzist> || Cmd<printf>;
    is $cmd,'printf','Cmd or junction returns the one that exists';
}

{
    my $bin = on {
        RHEL { '/usr/bin' }
        Any  { '/bin' }
    };
    is Cmd<ls>.path, "$bin/ls" , 'Cmd<ls>.path';
    is Cmd<grep>.path, "$bin/grep", 'Cmd<grep>.path';
}
