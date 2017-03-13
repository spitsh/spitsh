use Test;

plan 18;

is ${printf "foo"},"foo","cmd works as a value";
ok ?${true},"cmd status true";
nok ?${false},"cmd status false";
ok !${false},'! prefix works with cmd';

is ${printf "foo" | sed 's/foo/bar/'},"bar","pipe works";
my $var = "foo";
is $var.${sed 's/foo/bar/'},"bar","pipe works with variable as input";

# , is optional after the first arg
is ${'printf' '%s' 'win'},'win','quoted cmd';
is ${'printf' '%s' 'win'},'win','quoted cmd with ,';
is ${"printf" '%s' 'win'},'win','double quoted cmd';
is ${"printf" '%s' 'win'},'win','double quoted cmd with ,';
is ${ (${printf 'printf'}) '%s' 'win'},'win','cmd from block expr with ,';
is ${ (${printf 'printf'}) '%s' 'win'},'win','cmd from block expr';

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
