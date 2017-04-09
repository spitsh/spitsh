use Test;

plan 9;

{
    my FD $fd .= next-free;
    nok $fd.is-open,"fd from .next-free shouldn't be open";
    my File $tmp .= tmp;
    $fd.open-w($tmp);
    ok $fd.is-open,".valid after open-w";
    $fd.write("hello");
    is $tmp.read,"hello",'.write';
    $fd.write(" world");
    is $tmp.read,"hello world",'.write again';

    $fd.close;
    nok $fd.is-open,"closed after .close";
    quietly { $fd.write("more text") }
    is $tmp.read,"hello world","write after .close";
}


{
    my File $file1 .= tmp;
    my $fd1 = $file1.open-w;
    ok $fd1.is-open,'File.open-w returns a open FD';
    $fd1.write("win");
    is $file1.read,"win","writing to the FD changes the file";

    my File $file2 .= tmp;
    my $fd2 = $file2.open-w;

    ok $fd1 != $fd2,'new file, FD is different';
}
