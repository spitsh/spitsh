use Test;

plan 18;

{
    my FD $fd .= next-free;
    nok $fd.is-open,"fd from .next-free shouldn't be open";
    my File $tmp .= tmp;
    $fd.open-w($tmp);
    ok $fd.is-open,".valid after open-w";
    $fd.write("hello");
    is $tmp.slurp,"hello",'.write';
    $fd.write(" world");
    is $tmp.slurp,"hello world",'.write again';

    $fd.close;
    nok $fd.is-open,"closed after .close";
    quietly { $fd.write("more text") }
    is $tmp.slurp,"hello world","write after .close";
}


{
    my File $file1 .= tmp;
    my $fd1 = $file1.open-w;
    ok $fd1.is-open,'File.open-w returns a open FD';
    $fd1.write("win");
    is $file1.slurp, "win","writing to the FD changes the file";

    my File $file2 .= tmp;
    my $fd2 = $file2.open-w;

    ok $fd1 != $fd2,'new file, FD is different';
    $fd1.close;
    $fd2.close;
}

{
    my File $multi-line .= tmp;
    $multi-line.write(<foo bar baz>);
    my $get  = $multi-line.open-r;
    if $get.get {
        is $~, 'foo', '1. get sets $~ correct value';
    }
    if $get.get {
        is $~, 'bar', '2. get sets $~ correct value';
    }
    if $get.get {
        is $~, 'baz', '3. get sets $~ correct value';
    }
    if not $get.get {
        nok $~, 'get sets $~ to empty';
    }

    $get.close;

    my $getc = $multi-line.open-r;
    if $getc.getc(1) {
        is $~, 'f',  'getc(1) reads 1 char to $~';
    }
    if $getc.getc(2) {
        is $~, 'oo', 'getc(2) reads 2 chars to $~';
    }
    if $*os ~~ Debian {
        skip ‘can't read newline with getc with debian yet’,1;
    } else {
        if $getc.getc(1) {
            is $~, "\n", 'getc(1) can read a newline into $~';
        }
    }
    $getc.close;
}

{
    my $next-free = FD.next-free;
    is $next-free, FD.next-free,
        ‘.next-free doesn't give a different FD unless it has been used’;

    my FD @fds;
    my FD $next;
    my $count = 0;
    while $next < $*max-fd {
        $next .= next-free;
        my $tmpfile = File.tmp;
        $tmpfile.write($count++);
        $next.open-r($tmpfile);
        @fds.push($next);
    }

    for ^@fds {
        @fds[$_].get;
        unless $~-->Int == $_ {
            flunk 'FD stress test';
        }
        @fds[$_].close;
    }
    ok @fds >= 4, "at least 4 file descriptors available";
}
