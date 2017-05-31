use Test; plan 4;

my $pkg1 = Pkg<telnet>;
my $pkg2 = Pkg<socat>;


if ! $pkg1 {
    ok .install, ".install $pkg1";
} else {
    pass ".install $pkg1 (already exists)";
}
ok $pkg1-->Cmd, "$pkg1 commmand installed";

if ! $pkg2 {
    ok .install, ".install $pkg2";
} else {
    pass ".install $pkg2 (already exists)";
}

ok $pkg2-->Cmd, "$pkg2 command installed";
