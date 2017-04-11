use Spit::Compile;

sub slurp-SETTING {
    <base EnumClass os List FD core-subs Any File Str Int Bool Pkg Cmd Locale checks>
    .map({ %?RESOURCES{"src/$_.spt"}.slurp })
    .join("\n");
}



my constant $src = slurp-SETTING();
my constant $SETTING = compile(
        $src,
        :target<stage2>,
        :!SETTING,
        :name<SETTING>,
    ).block;

sub get-SETTING is export {
    once do if %*ENV<SPIT_SETTING_DEV> {
        compile(
            slurp-SETTING(),
            :target<stage2>,
            :!SETTING,
            :name<SETTING>,
            :debug(%*ENV<SPIT_DEBUG_SETTING>),
        ).block;
    } else {
        $SETTING;
    }
}

my constant %core-lib is export = {
    Test => compile(
        %?RESOURCES{"core-lib/Test.spt"}.slurp,
        :target<stage2>,
        :name<Test>,
        :$SETTING,
    )
}

sub get-CORE-lib($name) is export {
    if %*ENV<SPIT_SETTING_DEV> {
        compile(
            %?RESOURCES{"core-lib/$name.spt"}.slurp,
            :target<stage2>,
            :name<Test>,
            SETTING => get-SETTING(),
        )
    } else {
        %core-lib{$name};
    }
}
