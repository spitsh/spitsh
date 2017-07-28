use Test; plan 9;
{
    class Foo {
        method second($a)~ { $self ~ $a ~ "baz"}
        method first($a)~  { $self.second($a) }
        method return-self^ { $self.uc }
        method is-foo? is no-inline { $self eq "foo" }
    }

    is Foo<foo>.first("bar"),"foobarbaz","methods can call other methods";
    is (Foo<foo>.first: "bar"), "foobarbaz", '.method: syntax';
    is Foo<foo>.return-self.WHAT, 'Foo', '* return on instance';

    ok Foo<foo>.is-foo, '-->Bool in Bool context';
    is Foo<foo>.is-foo, 1, '-->Bool in Str context';
    nok Foo<bar>.is-foo, '-->Bool in Bool context (false)';
    is Foo<bar>.is-foo, '', '-->Bool in Str context (false)';

    given Foo<foo> {
        is .first("bar"), "foobarbaz", 'topic method-call($a)';
        is (.first: "bar"), "foobarbaz", 'topic method-call: $a';
    }
}
