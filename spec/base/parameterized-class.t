use Test;

plan 10;

class Foo[Type] {
    static method doit(--> Type) { 3 }
    static method echo(Type $a --> Type)  { $a }
}

augment Foo {
    static method aug-echo(Type $a --> Type) { $a }
}

ok Foo[Int].doit ~~ Int,"Foo[Int].method returns Int";
ok Foo[Int] ~~ Foo, "Foo[Int] ~~ Foo";
nok Foo ~~ Foo[Int], "Foo !~~ Foo[Int]";
is Foo[Int].echo(5),5,"Foo[Int].echo --> Int";
is Foo[Str].echo("str"),"str","Foo[Str].echo --> Str";
is Foo[Int].aug-echo(5),5,"Foo[Int].aug-echo --> Int";
is Foo[Str].aug-echo("str"),"str","Foo[Str].aug-echo --> Str";
ok Foo[Int] ~~ Foo[Int],"Foo[Int] ~~ Foo[Int]";

is Foo[Int].WHAT,Foo[Int],"Foo[Int].WHAT eq Foo[Int]";
is Foo[Int],'Foo[Int]',"Foo[Int] as a string is Foo[Int]";
