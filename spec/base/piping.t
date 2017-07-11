use Test; plan 2;

{
    class Piping-Methods {

        method one~ is no-inline{
            $self.${cat}
        }
        method two~ is no-inline {
            $self.one;
        }

    }

    is Piping-Methods("foo\n").two.bytes, 4, ‘piping methods shouldn't lose newline’;
}

{
    # This tests that using a piped method as an argument to another
    # piped method with a different invocant stops the caller method
    # from being piped. If it doesn't you lose the invocant.
    # consider the following:
    # Does this return foo or bar?
    # method(){
    #   echo "foo" | echo $(cat)
    # }
    # echo "bar" | method
    # Answer: foo
    class A {
        # This one shouldn't get inlined
        method top-method~ is no-inline {
            A<bar>.a( $self.b );
        }
        method a($a)~ is no-inline {
            $self.${cat} ~ $a;
        }
        method b~ is no-inline {
            $self.${cat}
        }
    }

    is A<foo>.top-method, 'barfoo', 'works';
}
