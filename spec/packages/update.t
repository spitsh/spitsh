use Test;

plan 6;

ok Pkg.last-updated.valid || Pkg.last-updated eq "",
  '.last-updated is valid or empty before update';

Pkg.check-update;

ok Pkg.last-updated.valid, '.last-updated is valid';

sleep 1;

ok Pkg.last-updated lt now, '.last-updated lt than now()';
ok Pkg.last-updated.posix < now.posix, '.last-updated.posix than now.poisx';

nok Pkg.check-update, 'check-update returns False second time';

ok Pkg.update-pkglist, '.update-pkglist';
