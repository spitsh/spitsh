use Test;

plan 3;

ok $*git ~~ Cmd, 'git is a Cmd';
ok $*git.exists, 'referencing $*git installs it';
ok ${ $*git --version }.matches(/^git version/), '--version seems to work';
