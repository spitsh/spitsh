use Test;

plan 4;

{

    my Log @logs = eval(:log){
        eval{ say "out"; sleep 1; note "err" }.${sh >info/warn }
    }.${sh !>~};

    is @logs[0].level-name, 'info', '>info/warn (stdout)';
    is @logs[0].message, 'out', '>info/warn (stdout)';
    is @logs[1].level-name, 'warn', '>info/warn (stderr)';
    is @logs[1].message, 'err', '>info/warn (stderr)';
}
