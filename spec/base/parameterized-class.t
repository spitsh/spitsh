use Test;

plan 18;

{
    class Foo[Type] {
        static method doit(--> Type) { 3 }
        static method echo(Type $a --> Type)  { $a }
    }

    augment Foo {
        static method aug-echo(Type $a --> Type) { $a }
    }

    ok Foo[Int].doit ~~ Int,"Foo[Int].method returns Int";

    is Foo[Int].echo(5),5,"Foo[Int].echo --> Int";
    is Foo[Str].echo("str"),"str","Foo[Str].echo --> Str";
    is Foo[Int].aug-echo(5),5,"Foo[Int].aug-echo --> Int";
    is Foo[Str].aug-echo("str"),"str","Foo[Str].aug-echo --> Str";

    is Foo[Int].WHAT,Foo[Int],"Foo[Int].WHAT eq Foo[Int]";
    is Foo[Int],'Foo[Int]',"Foo[Int] as a string is Foo[Int]";

    ok Foo[Int] ~~ Foo, "Foo[Int] ~~ Foo";
    ok Foo[Int] ~~ Foo[Int],"Foo[Int] ~~ Foo[Int]";
    nok Foo ~~ Foo[Int], "Foo !~~ Foo[Int]";
    ok Foo[Int] ~~ Foo[Str],'Foo[Int] ~~ Foo[Str]';
    nok Foo[Str] ~~ Foo[Int],'Foo[Str] !~~ Foo[Str]';
}

{
    class Aint is Int { }
    class Abool is Bool { }

    class Bar[One,Two] {
        static method ~one-two(One $one,Two $two) { $one ~ $two }
    }

    ok Bar[Aint,Abool] ~~ Bar[Aint,Abool], 'Bar[A,B] ~~ Bar[A,B]';
    ok Bar[Aint,Abool] ~~ Bar[Int,Bool],   'Bar[A,B] ~~ Bar[Int,Bool]';
    ok Bar[Aint,Abool] ~~ Bar[Str,Str],    'Bar[A,B] ~~ Bar[Str,Str]';
    nok Bar[Int,Bool]  ~~ Bar[Aint,Abool], 'Bar[Int,Bool] ~~ Bar[A,B]';
    is Bar[Aint,Abool].one-two(1,False),'1', 'call method on multi param class 1';
    is Bar[Aint,Abool].one-two(1,True),'11', 'call method on multi param class 2';
}
