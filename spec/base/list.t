use Test;

plan 38;

{
    my @a;
    is @a.WHAT,'List[Str]','empty my @a; has correct type';
    is +@a,0,'elems of empty list';
}

{
    my @a = <one>;
    is @a.WHAT,'List[Str]',
       'correct type assigning to square brackets with single element';
    is +@a,1,'correct elems after assigning to square brackets with single element'
}

{
    my @a = 0..5;
    is @a.WHAT,'List[Int]','@a = 0..5 has correct type';
    is @a[3] + @a[4],7,'range types array correctly';
    is +@a,6,'0..5 .elems';
}

{
    my @a = 0^..5;
    is +@a,5,'0^..5 .elems';
    is @a[0],1,'0^..5 has 1 as first element';
    is @a[4],5,'has 5 as last element';
}

{
    my Int @a;
    @a = ^5,42,1337;
    is +@a,7,'my Int @a assigns correctly';
}

{
    my Int @a = 42;
    is +@a, 1,'single element array correct elems';
    is @a[0],42,'single element array returns correct value';
    is @a.WHAT,'List[Int]','@a = 0..5 has correct type';
}
{
    my @a;
    @a[0] = "foo";
    is @a[0],"foo",'assignment to @a[0] works';
}

{
    my @c = <foo bar>;
    @c.push("baz");
    is +@c,3,'elems after .push';
    is @c[2],"baz",".push";

    @c.shift;
    is +@c,2,'elems after .shift';
    is @c[1],'baz',".shift";

    @c.unshift("foo");
    is @c[2],"baz",'.unshift';
    is +@c,3,'elems after .unshift';

    @c.pop;
    is @c[1],'bar','.pop';
    is +@c,2,'elems after .pop';
}

{
    my @b;
    @b[1] = "bar";
    is @b[1],'bar','assignment to @b[1] works';
    nok @b[0],'@b[0] is still empty';

    @b[1337] = "baz";
    is @b[1337],"baz",'set a large index';
    nok @b[42],"other things still empty";
}

{
    my @d;
    @d.push("foo");
    is @d[0],"foo",'.push onto empty list';
    is +@d,1,".elems after .push on empty list";
}

{
    my @e;
    @e.unshift("foo");
    is @e[0],"foo",'.unshift onto empty list';
    is @e.elems,1,'.elems after .unshift on empty list';
}

{
    my @f;
    @f.push("much    whitespace  ");
    @f.push("   more  ");
    is @f[0],"much    whitespace  ",'.push preserves whitespace 1';
    is @f[1],"   more  ",'.push preserves whitespace 2';
}

{
    my @g = <one two three four>;
    @g[0] = "un";
    is @g[0],'un','overwrite [0]';
    @g[2] = "troix";
    is @g[2],'troix','overwrite [2]';
    @g[3] = 'quatre';
    is @g[3],'quatre','overwrite [3]';
    @g[4] = 'cinque';
    is @g[4],'cinque','assign to next position';
}

{
    my @h = <foo bar baz>;
    is @h.join(', '),'foo, bar, baz','.join(", ")';
}
