use Test;
plan 13;

{
    my Log $log = eval(:log){
        ${printf '%s' 'hello world' >info};
    }.${ sh !>~ >X };

    is $log.message, 'hello world',
      '.message after >info';

    is $log.path, 'printf',
      'default path is name of command';
}


{
    my Log @log = eval(:log){
        ${printf '%s\n' 'hello world' >info};
        ${printf '%s\n' 'hello again' >info};
    }.${ sh !>~ >X };

    is @log[0].path, 'printf',
      '1. default path is name of command (two logs)';

    is @log[0].message, 'hello world',
      '1. .message after >info (two logs)';

    is @log[1].path, 'printf',
      '2. default path is name of command (two logs)';

    is @log[1].message, 'hello again',
      '2. .message after >info (two logs)';
}

{
    my Log @log = eval(:log){
        ${printf '%s' 'hello world' >info};
        ${printf '%s' 'hello again' >info};
    }.${ sh !>~ >X };

    is @log[0].path, 'printf',
    '1. default path is name of command (two logs no nl)';

    is @log[0].message, 'hello world',
    '1. .message after >info (two logs no nl)';

    is @log[1].path, 'printf',
    '2. default path is name of command (two logs no nl)';

    is @log[1].message, 'hello again',
    '2. .message after >info (two logs no nl)';
}

{
    my Log $log = eval(:log){ ${printf '%s' 'hello world' >info()} }.${sh !>~ >X};

    is $log.path, $:log-default-path, '>info() sets to path to $:log-default-path';
}

{
    my Log $log = eval(:log){ ${printf '%s' 'hello world' >info('mypath')} }.${sh !>~ >X};
    is $log.path, 'mypath', ‘>info('mypath')’;
}

{
    my Log $log = eval(:log){ ${printf '%s' 'hello world' >info('mypath')} }.${sh !>~ >X};
    is $log.path, 'mypath', ‘>info('mypath')’;
}
