use Test;
plan 2;

my $canary = False;

{
    sub ~foo() is impure {
        $canary = True;
        "bar";
    }

    my $res = foo();

    is $res,"bar",'return value from impure';
    ok $canary,   'variable side effects kept';
}
