use Test; plan 5;

{
    my @files = (File.tmp, File.tmp, File.tmp);
    is @files.WHAT, 'List[File]', '(File.tmp,File.tmp) --> List[File]';
    ok @files[2], 'file in list exists';
    ok @files.remove, 'List[File].remove';
    nok @files[2], ‘file in list doesn't exist after .remove’;
}

{
    my @files = (File.tmp, File.tmp, File.tmp);
    @files[0].write("foo");
    @files[1].write("bar");
    @files[2].write("baz");
    is @files.cat, "foobarbaz", 'List[File].cat';
}
