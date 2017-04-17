use Test;

plan 3;

if $*os ~~ Alpine {
    skip-rest("alpine doesn't support Pkg.install yet");
} else {
    ok $*git ~~ Cmd, 'git is a Cmd';
    ok $*git.exists, 'referencing $*git installs it';
    ok ${ $*git --version }.matches(/^git version/), '--version seems to work';
}
