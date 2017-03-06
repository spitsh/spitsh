use Test;

plan 18;
{
    my @a = <one two three>;

    my $res;
    for @a {
        pass "iterated $_";
        $res ~= $_;
    }

    is $res,"onetwothree","iterated in right order";

    for ^@a {
        if $_ == 0 {
            is @a[$_],"one","first element correct";
        } elsif $_ == 1 {
            is @a[$_],"two","second element is correct";
        } elsif $_ == 2 {
            is @a[$_],"three","third element is correct";
        } else {
            flunk "iterated too many times";
        }
    }
}


for 4,5 {
    if $_ == 5 {
        pass "4,5 results in $_ being an Int"
    }
}

{
    for 1 {
        for 2 {
            is $_,2,'nested loop ran';
        }
        is $_,1,q<nested loop didn't override $_>;
    }
}

{
    my $i = 0;
    for <one two three> -> $arg {
        if $i == 0 {
            is $arg,'one',"$i -> \$arg";
        } elsif $i == 1 {
            is $arg,'two',"$i -> \$arg";
        } elsif $i == 2 {
            is $arg,'three',"$i -> \$arg";
        }
        $i++;
    }

    for <IDONT_E_XITSttt ME_@niEErthr> -> Cmd $cmd {
        nok $cmd,'-> Cmd $cmd';
    }
}


pass "statement-mod for $_" for ^3;
