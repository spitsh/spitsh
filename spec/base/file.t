use Test;

plan 29;

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
