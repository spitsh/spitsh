use Test; plan 4;

{
    given File.tmp {
        my $before = .mtime;
        ok .ctime eq .mtime, '.ctime eq .mtime after first created';
        sleep 1;
        .write("goof");
        my $diff = .mtime.posix - $before.posix;
        ok $diff >= 1 || $diff <= 2,     '.mtime is small';
        ok .ctime eq .mtime, '.ctime eq .mtime after writing';
        sleep 1;
        .chmod(777);
        ok .ctime gt .mtime, 'ctime > mtime after chmod';
    }
}
