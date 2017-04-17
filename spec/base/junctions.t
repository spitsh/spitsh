use Test;

plan 138;

my $true = True;
my $false = False;

{
    ok (True and True) ,'true <and> works';
    ok True && True, ' true && works';

    ok (True or False), '<or> works';
    ok (True || False), '<||> works';

    ok (!True or True), "<!> precedence is correct";
    nok !(False or True),"!(False or True)";

    ok (True or False and True),"double junction (T | F & T)";
}

{
    ok ($true and $true) ,'true <and> works';
    ok $true && $true, ' true && works';
    nok ($false || $false), "false || false";

    ok ($true or $false), '<or> works';
    ok ($true || $false), '<||> works';

    ok (!$true or $true), "<!> precedence is correct";
    nok (!$true or $false),"!T | F";
    ok (!$false && $true),'!F && T';
    nok !($false or $true),'!(F | T)';
    ok !($false or $false), '(F | F)';

    ok ($true or $false and $true),'double junction ($T | $F & $T)';
    nok !($true or $false and $true),'neg double junction !($T | $F & $T)';
}

{
    nok ?${false} || ?${false},'?${false} || ?${false}';
}

{
    my $x;
    $x ||= "foo";
    $x ||= "bar";
    is $x,'foo','||=';
    $x &&= "bar";
    is $x,'bar','&&=';
    $x = False;
    $x &&= 'bar';
    nok $x,'$x &&= "string", still false when $x is false';

    my $y;
    my $glarb = "woot";
    $y ||= 'foo}';
    is $y,'foo}', '||= with } in value';
    $y = False;
    $y ||= “foo$glarb"\$glarb}”;
    is $y, 'foowoot"$glarb}','||= "lotsofcrazystuff}"';
    $y = False;
    $y ||= 'foo{';
    is $y, 'foo{', '||= with { in value';


    my $z;
    # Super weird situation where on bash's /bin/sh where you do
    # "${a:='...'}" it will include the single quotes in a but if
    # you do ${a:=...} outside of "" it won't (!?)
    ($z ||= "\n") || flunk "shouldn't have got here";
    is $z, "\n", '||= \\n}';
}

{

    my @a =        1,1,1,1,0,0,0,0;
    my @b =        0,1,1,0,0,1,1,0;
    my @c =        0,0,1,1,0,0,1,1;

    my @and-and  = 0,0,1,0,0,0,0,0;
    my @or-and   = 0,0,1,1,0,0,1,0;
    my @b-or-and = 1,1,1,1,0,0,1,0;
    my @and-or   = 0,1,1,1,0,0,1,1;
    my @b-and-or = 0,1,1,1,0,0,0,0;
    my @or-or    = 1,1,1,1,0,1,1,1;

    for ^@and-and {
        is @a[$_] && @b[$_] && @c[$_],@and-and[$_],"@a[$_] && @b[$_] && @c[$_]";
        if @a[$_] && @b[$_] && @c[$_]  {
            is @and-and[$_],1,"Bool @a[$_] && @b[$_] && @c[$_]";
        } else {
            is @and-and[$_],0,"Bool @a[$_] && @b[$_] && @c[$_]";
        }
    }
    for ^@or-and {
        is @a[$_] || @b[$_] && @c[$_],@or-and[$_],"Str @a[$_] || @b[$_] && @c[$_]";
        if @a[$_] || @b[$_] && @c[$_] {
            is @or-and[$_],1,"Bool @a[$_] || @b[$_] && @c[$_]";
        } else {
            is @or-and[$_],0,"Bool @a[$_] || @b[$_] && @c[$_]";
        }
    }
    for ^@b-or-and {
        is @a[$_] || ( @b[$_] && @c[$_] ),@b-or-and[$_],"Str @a[$_] || ( @b[$_] && @c[$_] )";
        if @a[$_] || (@b[$_] && @c[$_]) {
            is @b-or-and[$_],1,"Bool @a[$_] || ( @b[$_] && @c[$_] )";
        } else {
            is @b-or-and[$_],0,"Bool @a[$_] ||  (@b[$_] && @c[$_] )";
        }
    }
    for ^@and-or {
        is @a[$_] && @b[$_] || @c[$_],@and-or[$_],"Str @a[$_] && @b[$_] || @c[$_]";
        if @a[$_] && @b[$_] || @c[$_] {
            is @and-or[$_],1,"Bool @a[$_] && @b[$_] || @c[$_]";
        } else {
            is @and-or[$_],0,"Bool @a[$_] && @b[$_] || @c[$_]";
        }
    }
    for ^@b-and-or {
        is @a[$_] && ( @b[$_] || @c[$_] ),@b-and-or[$_],"Str @a[$_] && ( @b[$_] || @c[$_] )";
        if @a[$_] && (@b[$_] || @c[$_]) {
            is @b-and-or[$_],1,"Bool @a[$_] && ( @b[$_] || @c[$_] )";
        } else {
            is @b-and-or[$_],0,"Bool @a[$_] && ( @b[$_] || @c[$_] )";
        }
    }
    for ^@or-or {
        is @a[$_] || @b[$_] || @c[$_],@or-or[$_],"Str @a[$_] || @b[$_] || @c[$_]";
        if @a[$_] || @b[$_] || @c[$_] {
            is @or-or[$_],1,"Bool @a[$_] || @b[$_] || @c[$_]";
        } else {
            is @or-or[$_],0,"Bool @a[$_] || @b[$_] || @c[$_]";
        }
    }
}

{
    is $false || ($false && ($false || $true) ),$false,"F || (F && (F || T) )";
    is $true &&  ($true || ($true && $true)) && $false,$false,"T && (T || (T && T))";
    is $true || $false && $false || $true,$true,"T || F && F || T";
}

{
    class Foo {
        method ?Bool { $self eq 'foo' }
    }

    is Foo<bar> && Foo<baz>,"bar","Foo<bar> && Foo<baz>";
    is Foo<foo> && Foo<bar>,'bar','Foo<foo> && Foo<bar>';
    is Foo<bar> || Foo<baz>,'baz','Foo<bar> || Foo<baz>';
    is Foo<foo> || Foo<bar>,'foo','Foo<foo> || Foo<bar>';
    my $es = "";
    is Foo("$es foo") && Foo<baz>," foo",'Foo{weird stuff} && Foo<baz>';

    Foo<foo> && pass "Foo<foo> in Any context";
}

{
    class A { }
    class B is A { }
    class C is A { }
    # Need to put ~ in front because in Any context I'm not
    # sure what a junction should return yet
    is (~($true && B<foo> || C<foo>)).WHAT,'A','junction.WHAT returns common parent';
}

{
    my $tmp;
    ?($true || $tmp);
    $true || $tmp;
    pass "Any context ending in var doesn't cause syntax error";
}

{
    class Bar {
        method ?Bool { $self.${grep -Eq $self} }
    }

    is Bar<f> || $true,'f',   '1. .Bool inlined to cmd canary';
    is Bar<f> && $true,True,  '2. .Bool inlined to cmd canary';
    is Bar<^f> || $true,True, '3. .Bool inlined to cmd canary';
    is Bar<^f> && $true,'^f', '4. .Bool inlined to cmd canary';
}
