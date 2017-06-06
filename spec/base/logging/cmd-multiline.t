use Test; plan 7;

{
    my Log @log = eval(:log){ ${ printf 'foo\nbar\nbaz' >info } }.${sh !>~};

    is @log[0].message, 'foo', '1. .message';
    is @log[1].message, 'bar', '2. .message';
    is @log[2].message, 'baz', '3. .message';
}


{
    my Log @log = eval(:log){
        ${ printf 'foo\nbar\nbaz' >fatal };
        sleep 1;
        info ‘shouldn't get here’;
    }.${sh !>~};

    is @log[0].message, 'foo', '1. .message (fatal)';
    is @log[1].message, 'bar', '2. .message (fatal)';
    is @log[2].message, 'baz', '3. .message (fatal)';
    nok @log[3], 'multiline fatal killed process';
}
