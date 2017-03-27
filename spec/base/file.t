use Test;

plan 27;

{
    my File $file .= tmp;
    ok $file.exists,'.tmp';
    ok $file,'File.Bool = File.exists';
    $file.remove;
    nok $file.exists,'.remove';
    nok $file,'File.Bool = File.exists (false)';
    $file.create;
    ok $file.exists,'.create';
    END { nok $file.exists,"tempfiles should be rm by END" }
}

{
    my File $file .= tmp;
    ok $file.writable,'.writable';
    ok $file.w, '.w';

    $file.write("foo");

    is $file.read,"foo",".read .write";
    is $file.size,3,'.size';
    is $file.s,3,'.s';

    $file.append("bar");
    is $file.read,"foobar",'.append';

    $file.push("baz");
    is $file.read,"foobar\nbaz",'.push';
    is $file.read.${cat},"foobar\nbaz",'.read.${cat}';

    is $file.size,10,'.size changes after appending';

    END { nok $file.exists,"tempfiles should be rm by END" }
}

{
    my File $file .= tmp;
    my @a;
    for <foo bar baz> {
        @a.push($_);
        $file.push($_);
        is $file.read,@a,".push behaves like Array.push ($_)";
    }

    is $file.read,"foo\nbar\nbaz",'loop with .push behaves like array';

    $file.append("\n");
    $file.push("end");
    @a.push("end");
    is $file.read,@a,".push when the last line already has \\n doesn't duplicate";
}

{
    my $str = "foood";
    given File.tmp {
        .write($str);
        .subst('o','e');
        is .read,"feood",".subst replaces first occurrence";
        .subst('o','e',:g);
        is .read,"feeed",".subst(:g), replaces all ocurrences";

        .write(<foo bar baz>);
        .subst("oo\nba","ood\n\nca");
        is .read,"food\n\ncar\nbaz",'.subst with \\n';
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
        is .read[1],'bar','.read[1]';
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
