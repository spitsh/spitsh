use Spit::Compile;
use Spit::PRECOMP::SETTING;

my constant %core-lib is export = {
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
}
