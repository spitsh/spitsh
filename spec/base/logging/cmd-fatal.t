use Test; plan 5;

{
    my Log @log = eval(:log) {
        ${ printf 'you die now' >fatal };
        # need to sleep atm until we can handle waiting for logging process
        sleep 1;
        info ‘I shouldn't get logged’;
    }.${sh !>~};

    is @log[0].path, 'printf', '>fatal .path is the command';
    is @log[0].message, 'you die now', '>fatal .message';
    is @log[0].level-name, 'fatal', '>fatal .level';
    nok @log[1], ‘thing after >fatal log shouldn't get printed’;
}

{
    my Log $log = eval(:log){
        ${ printf '' >fatal };
        sleep 1;
        info 'hello world';
    }.${sh !>~ };

    is $log.message, 'hello world', ‘printing nothing to fatal didn't kill it’;
}
