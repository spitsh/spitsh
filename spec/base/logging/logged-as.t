use Test; plan 6;

constant $logged-as = "\c[BELL]";
my Log @logs = eval(:log){
    constant $printf is logged-as($logged-as) = "printf";
    ${ $printf '%s' 'info' >info };
    ${ $printf '%s' 'warn' >warn };
    ${ $printf '%s' 'info' >info('information') };
    ${ $printf '%s' 'warn' >warn('warning') };
}.${sh !>~};

is @logs[0].path, $logged-as, '.path (info)';
is @logs[0].level-name, 'info', '.level-name (info)';
is @logs[1].path, $logged-as, '.path (warn)';
is @logs[1].level-name, 'warn', '.level-name (warn)';
is @logs[2].path, "$logged-as:information", ‘.path >info('information')’;
is @logs[3].path, "$logged-as:warning", ‘.path >warn('warning')’;
