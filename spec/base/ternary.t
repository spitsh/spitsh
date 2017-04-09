use Test;

plan 17;

my $true = True;
my $false = False;
{
    is $true ?? "true" !! "false","true","true ?? A !! B";
    is True ?? "true" !! "flase","true","CT True ?? A !! B";
    is $false ?? "true" !! "false","false","false ?? A !! B";
    is False ?? "true" !! "false","false","CT False ?? A !! B";
    is $true ?? "true1" !! $true ?? "true2" !! "false","true1","true ?? A !! true ?? B !! C";
    is $false ?? "true1" !! $true ?? "true2" !! "false","true2","false ?? A !! true ?? B !! C";
    is $false ?? "true1" !! $false ?? "true2" !! "false","false","false ?? A !! false ?? B !! C";

    is $true ?? $true ?? "A" !! "B" !! "C","A",'true ?? true ?? A !! B !! C';
    is $true ?? $false ?? "A" !! "B" !! "C","B",'true ?? false ?? A !! B !! C';
    is $false ?? $true ?? "A" !! "B" !! "C","C",'false ?? true ?? A !! B !! C';
    is $false ?? $false ?? "A" !! "B" !! "C","C",'false ?? false ?? A !! B !! C';
}

{
    class A { }
    class B is A { }
    class C is A { }
    is ($true ?? B<foo> !! C<foo>).WHAT,'A', '(?? !!).WHAT returns common parent';
}

{
    class Foo {
        method ?Bool { $self eq 'foo' }
    }
    is Foo<foo> ?? 'true' !! 'false','true','?? !! boolifies condition (true)';
    is Foo<bar> ?? 'true' !! 'false','false','?? !! boolifies condition (false)';
}

{
    my $res = Alpine ~~ Debian ?? "lose" !! "win";
    is $res,"win",'Alpine ~~ Debian ??';
    $res = Ubuntu ~~ Debian ?? "win" !! "lose";
    is $res,"win",'Ubuntu ~~ Debian ??';
}

{
    (${true} ?? ${true} !! ${true}) && pass 'ternary as condition';
}
