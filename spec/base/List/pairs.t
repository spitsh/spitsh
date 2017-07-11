use Test;
plan 3;

{
    my @a = <zero one two three>;

    is @a.pairs, (0 => 'zero', 1 => 'one', 2 => 'two', 3 => 'three'),
       '<zero one two three>.pairs';

    my @files = File<foo.txt bar.txt>;
    ok @files.pairs[0].key ~~ Int, '.pairs keys are Ints';
    ok @files.pairs[0].value ~~ File, '.pairs value type is preserved';
}
