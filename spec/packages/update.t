use Test;

plan 5;

ok Pkg.last-updated.valid, '.last-updated is valid';
ok Pkg.last-updated.posix < now.posix, '.last updated is older than now()';

Pkg.check-update;

nok Pkg.check-update, 'check-update returns False second time';

my $before = Pkg.last-updated;
sleep 1;
ok Pkg.update-pkglist, '.update-pkglist';

ok Pkg.last-updated.posix > $before.posix, 'update-pkglist really does';
