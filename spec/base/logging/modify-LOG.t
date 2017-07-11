use Test;

plan 24;

{
    my Log @log = eval(:log){
        $:LOG = $:OUT;
        debug 'hello debug';
        info 'hello info';
        warn 'hello warn';
        error 'hello error';
    }.${sh !>X ($:OUT)>~};

    my $i = 0;
    my @levels = @:log-levels;
    @levels.shift;
    @levels.pop;

    for @levels {
        my $level-name = .key;
        my $sym        = .value;

        ok @log[$i].date, "Log.date ($level-name)";
        is @log[$i].level-name, $level-name, ".level-name symbol ($level-name)";
        is @log[$i].level-sym, $sym,         ".level-sym ($level-name)";
        is @log[$i].level, ($i + 1),         ".level ($level-name)";
        is @log[$i].path, $:log-default-path, ".path ($level-name)";
        is @log[$i].message, "hello $level-name", "log message ($level-name)";

        $i++;
    }
}
