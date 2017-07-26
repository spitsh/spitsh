use Spit::Compile;
use Spit::Util :sha1;
use Spit::Src;

my constant $src = slurp-SETTING();

my constant $SETTING is export = do {
    note "precompiling SETTING";
    compile(
        $src,
        :target<stage2>,
        :!SETTING,
        :name<SETTING>,
        :debug(%*ENV<SPIT_DEBUG_SETTING>)
    ).block;
}

my constant $SETTING-sha1 is export = sha1-SETTING;
