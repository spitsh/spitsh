use Spit::Compile;
use Spit::Util :sha1, :touch;

sub slurp-SETTING {
    <base EnumClass os List FD core-subs Any File Str Int Bool Regex Pkg Cmd Locale checks>
    .map({ %?RESOURCES{"src/$_.spt"}.slurp })
    .join("\n");
}



my constant $src = slurp-SETTING();
my constant $SETTING = compile(
        $src,
        :target<stage2>,
        :!SETTING,
        :name<SETTING>,
        :debug(%*ENV<SPIT_DEBUG_SETTING>)
    ).block;
my constant $src-sha1 = sha1($src);


sub get-SETTING is export {
    once do if %*ENV<SPIT_SETTING_DEV> {
        my $now-src = slurp-SETTING();

        if $src-sha1 ne sha1 $now-src {
            my $this-file = $?FILE.subst(/' ('[<![)]>.]*')'/,'').IO;
            if $this-file.w {
                touch $this-file;
                note "SETTING was outdated. Re-run to recompile it.";
                exit(0);
            }
            else {
                die "'$this-file' isn't writbale so I can't recompile the SETTING";
            }
        } else {
            $SETTING;
        }
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
