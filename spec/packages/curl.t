use Test;

plan 4;

if $*os ~~ Alpine {
    skip-rest("alpine doesn't support Pkg.install yet");
} else {
    if not Cmd<curl> {
        nok ?Pkg<curl>,"not Cmd<curl> means not Pkg<curl>";
        ok Pkg<curl>.install,'Pkg<curl>.install';
        ok Cmd<curl>,'curl Cmd exists after .install';
    } else {
        skip("curl already installed",2);
        ok ?Pkg<curl>,"Cmd<curl> means Pkg<curl>";
    }

    my @version = Pkg<curl>.version.split('.')-->List[Int];
    # curl v7 was released in early 2000s so it should be at least that
    ok @version[0] >= 7,'major version > 7';
}
