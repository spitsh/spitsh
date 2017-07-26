use Spit::Compile;
use Spit::PRECOMP::SETTING;
use Spit::Src;

my constant %core-lib is export = do {
    note "precompiling core-lib";
    %(
        Test => compile(
            %?RESOURCES{"core-lib/Test.sp"}.slurp,
            :target<stage2>,
            :name<Test>,
            :$SETTING,
        ),

        DigitalOcean => compile(
            %?RESOURCES{"core-lib/DigitalOcean.sp"}.slurp,
            :target<stage2>,
            :name<DigitalOcean>,
            :$SETTING,
        )

    )

}

my constant $core-lib-sha1 is export = sha1-core-lib();
