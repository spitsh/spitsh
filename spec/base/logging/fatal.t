use Test; plan 8;

{
    my Log @log = eval(:log){
        fatal 'you die now';
        info ‘I shouldn't get logged’;
    }.${sh !>~};
    is @log[0].path, $:log-default-path, '&fatal .path is the default path';
    is @log[0].message, 'you die now', '&fatal .message';
    is @log[0].level-name, 'fatal', '&fatal .level';
    nok @log[1], ‘thing after fatal log shouldn't get printed’;
}

{
    my Log @log = eval(:log){
        die "you die now";
        info ‘I shouldn't get logged’;
    }.${sh !>~};

    is @log[0].path, $:log-die-path, '&die .path is the default path';
    is @log[0].message, 'you die now', '&die .message';
    is @log[0].level-name, 'fatal', '&die .level';
    nok @log[1], ‘thing after die shouldn't get printed’;
}
