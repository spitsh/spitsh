use Spit::Util :sha1;

sub slurp-SETTING is export {
    <base EnumClass os List FD core-subs Any File Str Int Bool Regex Pkg Cmd
    Locale PID Git checks commands HTTP Docker>
    .map({ %?RESOURCES{"src/$_.spt"}.slurp })
    .join("\n");
}

sub sha1-SETTING is export {
    sha1 slurp-SETTING;
}
