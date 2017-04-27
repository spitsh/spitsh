use Test;

plan 27;

is ${printf "foo"},"foo","cmd works as a value";
ok ?${true},"cmd status true";
nok ?${false},"cmd status false";
ok !${false},'! prefix works with cmd';

is ${printf "foo" | sed 's/foo/bar/'},"bar","pipe works";
my $var = "foo";
is $var.${sed 's/foo/bar/'},"bar","pipe works with variable as input";

is ${'printf' '%s' 'win'},'win','quoted cmd';
is ${"printf" '%s' 'win'},'win','double quoted cmd';
is ${ (${printf 'printf'}) '%s' 'win'},'win','cmd inside parents inside cmd';
is ${ ${printf 'printf'} '%s' 'win'},'win','cmd inside cmd';

is ${printf 'foo' >X },'','>X';

{
    my $data = eval{ $*OUT.write("1"); $*ERR.write("2") };

    is $data.${sh *>X},'','*>X';
    is $data.${sh *>~},"12",'*>~';
    is $data.${sh !>~ >X},'2','>X !>~';
    is $data.${sh !>$?CAP >$*NULL},'2','!>$?CAP >$*NULL';
}


{
    my $cmd = Cmd<nOrtExist> || Cmd<AlsOnotzist> || Cmd<printf>;
    is $cmd,'printf','Cmd or junction returns the one that exists';
}

my $a = <one two three>;
{
    is ${printf '%s-%s-%s' $a }, "$a--", '$a in cmd doesn\'t flatten';
    is ${printf '%s-%s-%s' @$a}, 'one-two-three', '@$a in cmd flattens';
    is ${printf '%s-%s-%s' $@$a }, "$a--", '$@$a in cmd doesn\'t flatten';
    is ${printf '%s-%s-%s' @$@$a}, 'one-two-three', '@$@$a in cmd flattens';
}

{
    is ${printf '%s-%s-%s' (<one two three>)  }, 'one-two-three', '<...> list falttens in cmd';
    is ${printf '%s-%s-%s' $(<one two three>) }, "$a--", '$() itemizes in cmd';
    is ${printf '%s-%s-%s' @($a) },              'one-two-three', '@($) flattens in cmd';
    is ${printf '%s-%s-%s' @$(<one two three>)}, 'one-two-three', '@$() flattens in cmd';
}

{
    constant $b = <one two three>;
    constant @c = <one two three>;
    is ${printf '%s' $b}, $b, ‘$ list constants don't flatten’;
    is ${printf '%s-%s-%s' @c}, 'one-two-three', ‘@ list constants do flatten’;
}

{
    my File $file .= tmp;
    $file.write(<one two three>);
    is ${cat < $file},<one two three>, 'can read input from a file';
}
