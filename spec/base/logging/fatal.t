use Test; plan 4;

{
    my Log @log = eval(:log){
        fatal 'you die now';
        info ‘I shouldn't get logged’;
    }.${sh !>~};
    is @log[0].path, $*log-default-path, '&fatal .path is the defaul path';
    is @log[0].message, 'you die now', '&fatal .message';
    is @log[0].level, @*log-symbols[0], '&fatal .level';
    nok @log[1], ‘thing after fatal log shouldn't get printed’;
}
