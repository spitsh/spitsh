use Spit::Compile;
use Spit::PRECOMP::SETTING;
use Spit::Src;

my constant %core-lib is export = do {
    note "precompiling core-lib";
    @core-modules.map( -> $name {
        "$name" => compile(
            %?RESOURCES{"core-lib/$name.sp"}.slurp,
            :target<stage2>,
            :$name
            :$SETTING,
        )
    }).Map;
}

my constant $core-lib-sha1 is export = sha1-core-lib();
