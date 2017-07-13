use Test;

plan 10;

constant $src = eval{ say "out"; sleep 1; note "err" };

{
    my Log @logs = eval(:log){ $src.${sh >info/warn} }.${sh !>~};

    is @logs[0].level-name, 'info', '>info/warn (stdout)';
    is @logs[0].message, 'out', '>info/warn (stdout)';
    is @logs[1].level-name, 'warn', '>info/warn (stderr)';
    is @logs[1].message, 'err', '>info/warn (stderr)';
}

{
    my Log @logs = eval(:log){
        $src.${sh >info/warn("path")}
    }.${sh !>~};
    is @logs[0].level-name, 'info', '>info/warn("path") (stdout)';
    is @logs[0].message, 'out', '>info/warn("path") (stdout)';
    is @logs[0].path, 'path', '>info/warn("path") (stdout)';
    is @logs[1].level-name, 'warn', '>info/warn("path") (stderr)';
    is @logs[1].message, 'err', '>info/warn("path") (stderr)';
    is @logs[1].path, 'path', '>info/warn("path") (stdout)';
}
