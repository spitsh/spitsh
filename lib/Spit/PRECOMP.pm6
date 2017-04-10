use Spit::Compile;

constant $src = <base EnumClass os List FD core-subs Any File Str Int Bool Pkg Cmd Locale checks>
            .map({ %?RESOURCES{"src/$_.spt"}.slurp })
            .join("\n");


constant $SETTING is export =  compile(
    $src,
    :target<stage2>,
    :!SETTING,
    :name<SETTING>,
    debug => ($*DEBUG_SETTING || False),
).block;

constant %core-lib is export = {
    Test => compile(
        %?RESOURCES{"core-lib/Test.spt"}.slurp,
        :target<stage2>,
        :name<Test>,
        :$SETTING,
    )
}
