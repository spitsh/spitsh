use Test;
plan 2;

my $logfile = File.tmp;

my File $file = eval(:log, :$logfile){
    my File $:logfile;
    $:LOG = $:logfile.open-w;
    info 'first-log';
    info 'second-log';
}.${sh};

my @logs = $logfile.slurp-->List[Log];
is @logs[0].message, 'first-log', 'first log';
is @logs[1].message, 'second-log', 'second log';
