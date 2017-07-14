use Test; plan 4;

{
    my $a = { k => {a =>  1, b => 2} };
    my $b = { k => {a => 0, c => 3} };
    my $merged = $a.merge($b);
    my $answer = {
        right => { k => { a => 0, b => 2, c => 3}},
        wrong => { k => { a => 1, b => 2, c => 3}},
    };

    ok $merged ~~ $answer<right>, '$merged ~~ $answer<right>';
    nok $merged ~~ $answer<wrong>, '$merged !~~ $answer<wrong>';
    ok $answer<right> ~~ $merged, '$answer<right> ~~ $merged';
    nok $answer<wrong> ~~ $merged, '$answer<wrong> !~~ $merged';
}
