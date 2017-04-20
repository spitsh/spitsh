use Test;
plan 3;

ok eval{ my $a = Cmd<echo> || die "echo doesn't exist" }.${sh},
    'Cmd<echo> || die';

my $dies = eval{ my $a = Cmd<not_exist> || die "weee" };

quietly { is  $dies.${sh !>~ >X} , "weee", ‘die's message goes to STDERR’ };
quietly { nok  $dies.${sh} , 'code that dies exits with failure' };
