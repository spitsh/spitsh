use Test; plan 10;

{
    my $json = {
        one => "two",
        three => ("four","five"),
        five  => [
            {
                seven => <foo bar baz>,
                eight => ["hoo","jar","kaz"],
            },
            {
                "ayy\nlmao" => "nine",
                "orite\tthen\n" => "ten"
            }
        ],
    };

    is $json<one>, 'two', '$json<one>';
    is $json<three>.List, <four five>, '$json<three> (array)';
    is $json<three>[1], 'five', '$json<three>[1]';
    my $key = "eight";
    my $index = 2;
    is $json<five>[0]{$key}[$index], 'kaz',
       'variables as keys and indexes';

    is $json<five>[1]{"ayy\nlmao"}, 'nine',
      'newline in object key';
    is $json<five>[1]{"orite\tthen\n"}, 'ten',
      'tab in object key and ending in newline';

    is $json.keys,   <five one three>, '.keys';
    is $json.keys[1], "one", '.keys[1]';
    is $json<five>[1].values, <nine ten>, '.values';
    is $json<five>[1].values[0], "nine", '.values[0]';
}
