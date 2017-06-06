use Test;
plan 2;

my $src = eval(:log){
    eval(:log){
        eval(:log){ info 'hello world', 'three' }.${sh !>info("two") };
    }.${sh !>info("one")};
};

my Log $log = $src.${sh !>~};

is $log.path, 'one/two/three', 'nested log .path';
is $log.message, 'hello world',   'nested log has correct message';
