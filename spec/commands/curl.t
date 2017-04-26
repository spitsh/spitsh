use Test;

plan 3;

if $*os ~~ Alpine {
    skip-rest("alpine doesn't support Pkg.install yet");
} else {
    ok $*curl ~~ Cmd, 'curl is a Cmd';
    ok $*curl.exists, 'referencing $*curl installs it';
    ok ${ $*curl -V }.starts-with('curl 7.'), '--version seems work to';
}
