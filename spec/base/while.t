use Test;

plan 20;
{
    my $i = 0;

    while $i++ < 5 {
        pass "$i. while iteration";
    }

}

{
    my $i = 0;

    until $i++ == 5 {
        pass "$i. until iteration";
    }
}

class Foo is Int {
    method ?Bool { $self <= 8 }
    method squared(--> Foo) { $self * $self }
    method times2(--> Foo)  { $self + $self }
}

{
    my $i = 1;
    while Foo{$i}.times2 {
        if $i == 4 {
            is .WHAT, 'Foo','while: $_ has correct .WHAT';
            is .squared,64, 'while: $_ has correct value'
        }
        $i++;
    }
}

{
    my $i = 1;
    while Foo{$i}.times2 -> $var {
        if $i == 4 {
            is $var.WHAT,'Foo','while: -> $var has correct .WHAT';
            is $var.squared,64,'while: -> $var has correct value';
        }
        $i++;
    }
}

{
    my $i = 8;
    until Foo{$i}.times2 {
        if $i == 5 {
            is .WHAT, 'Foo','until: $_ has correct .WHAT';
            is .squared,100, 'until: $_ has correct value'
        }
        $i--;
    }
}

{
    my $i = 1;
    ++$i while $i < 5;
    is $i,5,"statement-mod while";
}

{
    my $i = 1;
    is $i,4,'statement-mod while and cond' if $i == 4 while ++$i < 5;
}
{
    my $i = 1;
    is $i,4,'statement-mod until and cond' if $i == 4 until ++$i == 5;
}

{
    my $i = 1;
    is .squared,64,'statement-mod while: $_ has correct value' if $i++ == 4 while Foo{$i}.times2;
}
