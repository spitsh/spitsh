use Test;

plan 16;

{
    my Log @log = eval(:log){
        $*LOG = $*OUT;
        error 'hello error';
        warn 'hello warn';
        info 'hello info';
        debug 'hello debug';
    }.${sh !>X ($*OUT)>~};

    for 1..^@*log-symbols -> $i {
        my $level = @*log-levels[$i];
        ok @log[$i-1].date, "Log.date ($level)";
        is @log[$i-1].level, @*log-symbols[$i], "log $level symbol ($level)";
        is @log[$i-1].path, $*log-default-path, "log default path ($level)";
        is @log[$i-1].message, "hello $level", "log message ($level)";
    }
}
