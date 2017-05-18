use Test; plan 2;
if File( ${ echo "/etc/hosts" } ) {
    is .owner, 'root', '/etc/hosts has correct owner';
} # NO else because to test (cond && action) if optimization as well

is File</etc/hosts>.group, 'root', '/etc/hosts has correct group';

# {
#     my $file = File.tmp;

#     $file.chmod(400);
#     ok $file.readable,'400 .readable';
#     nok $file.executable,'400 ! .executable';
#     nok $file.writable,'400 ! .writable';

#     $file.chmod(200);
#     nok $file.readable,'200 .readable';
#     nok $file.executable,'200 .executable';
#     ok $file.writable,'200 .writable';

#     $file.chmod(100);
#     nok $file.readable,'100 .readable';
#     ok $file.executable,'100 .executable';
#     nok $file.writable,'100 .writable';
# }
