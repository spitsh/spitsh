use Spit::Util :sha1;

sub slurp-SETTING is export {
    <base env EnumClass os List FD Str Any File Int Bool Regex Log Pkg Cmd
    Locale PID Git commands HTTP Docker Date JSON Pair Port SSH Host
    core-subs checks>
    .map({ %?RESOURCES{"src/$_.sp"}.slurp })
    .join("\n");
}

sub sha1-SETTING is export {
    sha1 slurp-SETTING;
}
