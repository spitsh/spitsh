use Spit::Compile;
use Spit::Util :sha1;
use Spit::SETTING;

my constant $src = slurp-SETTING();

constant $SETTING is export = do {
    note "precompiling SETTING";
    compile(
        $src,
        :target<stage2>,
        :!SETTING,
        :name<SETTING>,
        :debug(%*ENV<SPIT_DEBUG_SETTING>)
    ).block;
}

constant $SETTING-sha1 is export = sha1-SETTING;

my constant %core-lib is export = {
    Test => compile(
        %?RESOURCES{"core-lib/Test.spt"}.slurp,
        :target<stage2>,
        :name<Test>,
        :$SETTING,
    )
}
