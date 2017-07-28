use Test; plan 6;

my $pkg1 = $:Pkg-openssh-client;
my $pkg2 = Pkg<socat>;


if ! $pkg1 {
    ok .install, ".install $pkg1";
} else {
    pass ".install $pkg1 (already exists)";
}
ok Cmd<ssh>, "$pkg1 commmand installed";

if ! $pkg2 {
    ok .install, ".install $pkg2";
} else {
    pass ".install $pkg2 (already exists)";
}

ok $pkg1.installed, '.installed';
is $pkg1.installed, 1, '.installed str context';


ok $pkg2-->Cmd, "$pkg2 command installed";
