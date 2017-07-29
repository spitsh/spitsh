# some subs to help you get stuff from %?RESOURCES and check if they've changed
use Spit::Util :sha1;

sub slurp-SETTING is export {
    <base env EnumClass os List FD Str Any File Int Bool Regex Log Pkg Cmd
    Locale PID Git commands HTTP Docker Date JSON Pair Port SSH Host Service
    core-subs checks>
    .map({ %?RESOURCES{"src/$_.sp"}.slurp })
    .join("\n");
}

constant @core-modules = <Test DigitalOcean Rakudo>;

sub slurp-core-lib is export {
    @core-modules.map({ %?RESOURCES{"core-lib/$_.sp"}.slurp }).join("\n");
}

sub sha1-SETTING is export { sha1 slurp-SETTING() }

sub sha1-core-lib is export { sha1 slurp-core-lib() }
