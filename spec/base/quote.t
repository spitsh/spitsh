use Test;

plan 16;

{
    is '\'', "'",'single quotes can be escaped';
    is "\"",'"','double quotes can be escaped';
}

{
    is q|foo'bar'baz|,"foo'bar'baz",'q| ... |';
    is q|foo\zbar\|baz|,'foo' ~ '\\' ~ 'z' ~ 'bar|baz',
        'backslash + non-special character is treated literally';
}


{
    my $q = q|foo\|bar\|baz|;
    is $q,"foo|bar|baz",'q| \| |';
}

{
    is q{foo bar}, "foo bar",'q{ } - quoting with brackets works';
    is q{foo { bar } baz},'foo { bar } baz','balanced { } inside q{ }';
    is q{foo \{bar},'foo {bar',"escape opening bracket";
    is q{foo \}bar},'foo }bar',"escape closing bracket";
    is q{\\{}},'\\{}','escape \\ in q{...}';
}

{
    is "{ "foo " ~ "bar" }","foo bar",'{ } inside ""';
    is "\{ \"foo \" ~ \"bar\" }",'{ "foo " ~ "bar" }','\\{ inside ""';
}

{
    is "f{}oo{}","foo",'empty {} in "" doesn\'t goof';
}

{
    my $a = "bar";
    is "foo {$a.uc} baz",'foo BAR baz','{ } in double quotes doesn\'t eat whitespace';
}

{
    is "\c[BELL]",'🔔','\c[uniname]';
    is "\c[TWO HEARTS, BUTTERFLY]","💕🦋",'\c[uniname,uniname]';
}
