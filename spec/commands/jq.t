use Test;

plan 2;

my $installed-before = ?Cmd<jq>;

is '{ "foo" : "bar" }'.${$*jq -r '.foo'}, 'bar', '.foo';

END {
    ok Cmd<jq>.exists eq $installed-before,
      ‘jq was cleaned up (if it didn't exist already)’;
}
