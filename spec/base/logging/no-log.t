# tests for using logging constructs when logging is disabled
use Test;

plan 8;

is eval{ debug "hello world"}.${sh}, '', '&debug';
is eval{ info "hello world" }.${sh !>~ >X}, 'hello world', '&info';
is eval{ warn "hello world" }.${sh !>~ >X}, 'hello world', '&warn';
is eval{ error "hello world" }.${sh !>~ >X}, 'hello world', '&error';



is eval{ ${printf 'foo\nbar' >debug} }.${sh}, "", '>debug';
is eval{ ${printf 'foo\nbar' >info} }.${sh !>~ >X}, "foo\nbar", '>info';
is eval{ ${printf 'foo\nbar' >warn} }.${sh !>~ >X}, "foo\nbar", '>warn';
is eval{ ${printf 'foo\nbar' >error} }.${sh !>~ >X}, "foo\nbar", '>error';
