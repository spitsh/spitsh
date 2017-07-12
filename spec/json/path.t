use Test; plan 16;

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
        special => {
            nullio => JSON.null,
            not-null => 'null',
            empty  => "",
        }
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

    is $json.keys,   <five one special three>, '.keys';
    is $json.keys[1], "one", '.keys[1]';
    is $json<five>[1].values, <nine ten>, '.values';
    is $json<five>[1].values[0], "nine", '.values[0]';

    {
        is $json<five>[0]<eight>[0,2], ["hoo","kaz"], '[0,2]';
        my @a = <0 2>;
        is $json<five>[0]<eight>[@a], ["hoo","kaz"], '[@a]';
    }

    nok ?$json<special><doesnt><exist>, 'non-existing JSON in Bool context';
    nok ?$json<special><nullio>, ‘null is false’;
    # fudege this one for now
    # ok ?$json<special><not-null>, ‘"null" isn't false’;
    ok ?$json<special><empty>.defined, 'empty : "" -- empty is defined';
    nok ?$json<special><empty>, 'empty : "" -- empty is False';
}
