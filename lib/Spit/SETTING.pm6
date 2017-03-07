use Spit::Compile;
constant $src = <base EnumClass os List FD core-subs Any File Str Int Bool Pkg Cmd Locale checks>
            .map({ %?RESOURCES{"src/$_.spt"}.slurp })
            .join("\n");


our $SETTING is export = compile($src,:target<stage2>,
                                 :no-setting,
                                 :name<SETTING>,
                                 debug => ($*DEBUG_SETTING || False),
                                ).block;
