use Test;

plan 54;

{
    my File $file .= tmp;
    ok $file.exists,'.tmp';
    ok $file,'File.Bool = File.exists';
    $file.remove;
    nok $file.exists,'.remove';
    nok $file,'File.Bool = File.exists (false)';
    $file.touch;
    ok $file.exists,'.touch creates the file';
    END { nok $file.exists,"tempfiles should be rm by END" }
}

{
    my @files = (File.tmp, File.tmp, File.tmp);
    is @files.WHAT, 'List[File]', '(File.tmp,File.tmp) --> List[File]';
    ok @files[2], 'file in list exists';
    ok @files.remove, 'List[File].remove';
    nok @files[2], ‘file in list doesn't exist after .remove’;
}

{
    my File $file .= tmp;
    ok $file.writable,'.writable';
    ok $file.w, '.w';

    $file.write("foo");

    is $file.slurp,"foo",".slurp .write";
    is $file.size,3,'.size';
    is $file.s,3,'.s';

    $file.append("bar");
    is $file.slurp,"foobar",'.append';

    $file.push("baz");
    is $file.slurp,"foobar\nbaz",'.push';
    is $file.slurp.${cat},"foobar\nbaz",'.slurp.${cat}';

    is $file.size,10,'.size changes after appending';

    END { nok $file.exists,"tempfiles should be rm by END" }
}

{
    my @files = (File.tmp, File.tmp, File.tmp);
    @files[0].write("foo");
    @files[1].write("bar");
    @files[2].write("baz");
    is @files.cat, "foobarbaz", 'List[File].cat';
}

{
    my File $file .= tmp;
    my @a;
    for <foo bar baz> {
        @a.push($_);
        $file.push($_);
        is $file.slurp,@a,".push behaves like Array.push ($_)";
    }

    is $file.slurp,"foo\nbar\nbaz",'loop with .push behaves like array';

    $file.append("\n");
    $file.push("end");
    @a.push("end");
    is $file.slurp,@a,".push when the last line already has \\n doesn't duplicate";
}

{
    my $str = "foood";
    given File.tmp {
        .write($str);
        .subst('o','e');
        is .slurp,"feood",".subst replaces first occurrence";
        .subst('o','e',:g);
        is .slurp,"feeed",".subst(:g), replaces all ocurrences";

        .write(<foo bar baz>);
        .subst("oo\nba","ood\n\nca");
        is .slurp,"food\n\ncar\nbaz",'.subst with \\n';
    }
}

{
    my File $file = "/etc/hosts/";
    is $file.parent,"/etc",'.parent';
    is $file.name,'hosts','.name';
}

{
    given File.tmp {
        .write(<foo bar baz>);
        is .slurp[1],'bar','.slurp[1]';
    }
}

if File( ${ echo "/etc/hosts" } ) {
    is .owner, 'root', '/etc/hosts has correct owner';
} # NO else because to test (cond && action) if optimization as well

is File</etc/hosts>.group, 'root', '/etc/hosts has corrent group';


{
    my File $tmpdir .= tmp(:dir);
    ok $tmpdir.dir, 'tmp(:dir) returns a directory';

    my $child1 = $tmpdir.add('foo');
    is $child1, "$tmpdir/foo", '$child1.child';
    nok $child1, ‘.child doesn't cause directory to exist’;

    my $child2 = $child1.add('bar');
    is $child2, "$tmpdir/foo/bar", '$child2.child';

    $child2.mkdir.cd;

    ok $child2, 'child2 exists after .mkdir';
    ok $child1, 'child1 exists after .mkdir';
    is $child2, $?PWD, '.cd turns it into $?PWD';

    for <a b c> {
        my $top = $child2.add($_).mkdir;
        for <d e f> {
            my $under = $top.add($_).mkdir;
            for <g h i> {
                $under.add($_).touch; #ew
            }
        }
    }

    is $child2.find().elems, 3*3*3 + 3*3 + 3 + 1,
        '.find() found all files and directories';
    is $child2.find(name => /[ghi]$/).elems, 3*3*3,
        '.find(/../) found only those matching';

    END { nok $child2.exists, 'tmp(:dir) was cleaned up' }
}

{
    my $to-move = File.tmp;
    $to-move.write("win");
    my $dst = File.tmp;

    $to-move.move-to($dst);
    is $dst.slurp, 'win', 'move-to overwites dst';
    nok $to-move, ‘moved file doesn't exist in original location’;
}

{
    my $to-archive = File.tmp(:dir);
    $to-archive.add('foo.txt').touch;

    {
        File.tmp(:dir).cd;
        my $archive = $to-archive.archive;
        ok $archive, '.archive exists';
        my $extracted = $archive.extract;
        ok $extracted.d, 'extracted archive is a directory';
        ok $extracted.add('foo.txt'), 'foo.txt exists';
    }

    {
        File.tmp(:dir).cd;
        my $named-archive = $to-archive.archive(to => 'mytar.tgz');
        ok $named-archive, 'to => .archive exists';
        my $extracted = $named-archive.extract;
        ok $extracted.d, 'to => extracted archive is a directory';
        ok $extracted.add('foo.txt'), 'to => foo.txt exists';
    }
}

{
    given File.tmp {
        .write(<one two three four five six seven eight nine>);
        is .grep(/i.{1,2}$/), <five six nine>, '.grep';
        is .first(/i.{1,2}$/), <five>, '.first';
    }
}

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
