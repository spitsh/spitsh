use Test; plan 1;

# Weird bug where piping to log was broken on the second eval when logging is
# disabled on the first AND the first OS has no candidate in Str.log 🤦
eval(os => UNIXish, :!log){ warn "foo" }.${sh *>X};
ok eval(:log){ info "foo", "\c[SQUID]" }.${sh !>~}.contains("\c[SQUID]"), 'weird bug';
