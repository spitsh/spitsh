use Test; plan 5;
{
    my @h = <foo bar baz>;
    is @h.join(', '),'foo, bar, baz','.join(", ")';
    is @h.join('%s'),'foo%sbar%sbaz', ‘.join('%s')’;
    is @h.join("\t"),"foo\tbar\tbaz", '.join("\t")';
    is @h.join('\t'),'foo\tbar\tbaz', ‘.join('\t')’;
    is @h.join, 'foobarbaz', '.join';
}
