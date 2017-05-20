use Test;

plan 4;

{
    my Int @a = ();
    is @a, (), 'Int @a = ()';

    my Int @b = (1..3,(),4..6);
    is @b, <1 2 3 4 5 6>, '1..3,(),4..6';
}



if () {
    flunk 'empty is false'
} else {
    pass 'empty is true';
}

is (), <>, '() and <> are the same';
