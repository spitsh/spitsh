use Test;

plan 4;

{
    my $output = eval{ print "out"; sleep 1; $:ERR.write("err") };

    my Log @logs = eval(:log){ $output.${sh >info/warn} }.${sh !>~};

    is @logs[0].level-name, 'info', '>info/warn (stdout)';
    is @logs[0].message, 'out', '>info/warn (stdout)';
    is @logs[1].level-name, 'warn', '>info/warn (stderr)';
    is @logs[1].message, 'err', '>info/warn (stderr)';
}
