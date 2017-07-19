use Test; plan 34;

# Many of these tests groups should be moved into their own file;

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
    is q{\{ \}},'{ }', 'q{\{ \}}';
    is q{{ {'foo'} }}, ‘ {'foo'} ’, 'q{{ {...} }}';
}

{
    is qq{ {'foo'} }, ‘ {'foo'} ’, 'qq{ {..} }';
    is qq{{ {'foo'} }}, ' foo ', 'qq{{ {...} }}';
}

{
    is Q{foo\\bar}, 'foo\\\\bar', 'Q{foo\\\\bar}';
    is Q{\{ \}},'\{ \}', 'Q{\{ \}}';
    is ｢foo\\bar｣, 'foo\\\\bar', '｢foo\\\\bar｣';
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
    is "\c[BELL]",'🔔 ','\c[uniname]';
    is "\c[TWO HEARTS, BUTTERFLY]",'💕 🦋 ','\c[uniname,uniname]';
    is "\x[1f514]", "🔔", '\x[1f514]';
    is "\x[1F514]", "🔔", '\x[1F514]';
    is "I really \x[2661,2665,2764,1f495] Perl 6!", 'I really ♡♥❤💕 Perl 6!',
      '\x[2661,2665,2764,1f495]';
    is "\f", ${printf '\f'}, '\f';
    is "\x[0c]", "\f", '\x[0c]';
    is "\r", ${printf '\r'}, '\r';
    is "\x[0d]", "\r", '\x[0d]';
    is "\b", ${printf '\b'}, '\b';
    is "\x[08]", "\b", '\x[08]';
    is "\a", ${printf '\a'}, '\a';
    is "\x[07]", "\a", '\x[07]';
}
