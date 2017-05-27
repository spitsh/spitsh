use Spit::Util :sha1;

sub slurp-SETTING is export {
    <base EnumClass os List FD Str core-subs Any File Int Bool Regex Pkg Cmd
    Locale PID Git checks commands HTTP Docker Date JSON Pair Port Host>
    .map({ %?RESOURCES{"src/$_.spt"}.slurp })
    .join("\n");
}

sub sha1-SETTING is export {
    sha1 slurp-SETTING;
}
