use Test;

plan 36;

for <one two three> {

}

pass "empty for loop";


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

{
    my $a = <one two three>;
    for $a {
        is $_,$a,'for $a iterates once';
    }
    for $a,$a {
        is $_,$a,'for $a,$a iterates twice with the same value';
    }
}

{
    my $j = 0;
    for <one two three>,<four five six>,<seven eight nine> {
        $j++;
    }
    is $j, 9, 'for <...>,<...> iterates over all elements';
}

{
    my $k = 0;
    for $(<one two three>),<four five six>,<seven eight nine> {
        $k++;
    }
    is $k, 7, '$(...) in for'
}

{
    my $l = 0;

    for ("one","two" if ${true}), "three" {
        $l++;
    }

    is $l, 3, "if statements in loop list don't itemize";

    for ("one","two" if False) {
        $l++
    }
    is $l, 3, "a compile-time empty loop list doesn't iterate";

    for ("one","two" if ${false}) {
        $l++
    }
    is $l, 3, "a run-time empty loop doesn't iterate";
}

{
    my @m = for <one two three> { "foo$_" }
    is @m, <fooone footwo foothree>, "for loop as a value";
}

{
    my @n = for <one two three> { "foo",$_ }
    is @n, <foo one foo two foo three>, "block returns a list";
}

{
    for Cmd<echo printf> {
        is .WHAT, 'Cmd', 'for Cmd<...> { .WHAT }';
        ok .exists, 'for Cmd<...> { .exists }';
    }
}

{
    my @o = for <foo bar> { .chars }
    is @o.WHAT, 'List[Int]',
       'becomes List[whatever block returned] when assigning';

    is ( @(for <foo bar> { .chars,.chars }) ).WHAT, 'List[Int]',
       "block that returns List[Int] doesn't make expr return List[List[Int]]";
}

{
    is (for <one two three> { .uc }).${ sed 's/E/z/g' }, <ONz TWO THRzz>,
       "piping into command";
}


pass "statement-mod for $_" for ^3;
