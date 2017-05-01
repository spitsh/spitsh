use Test;

plan 27;

{
    class Foo[Type] {
        static method doit(--> Type) { 3 }
        static method echo(Type $a --> Type)  { $a }
        static method echo-list(Type $a --> List[Type]) { $a, $a }
        static method *return-type { "something" }
        static method first-in-list(Type @list --> Type) { @list[0] }
    }

    augment Foo {
        static method aug-echo(Type $a --> Type) { $a }
    }

    augment Foo[Int] {
        static method +double(Int $a) { $a + $a }
    }

    ok Foo[Int].doit ~~ Int,"Foo[Int].method returns Int";
    is Foo[Int].doit.WHAT, 'Int', '.method.WHAT is "Int"';
    is Foo[Int].echo(5),5,"Foo[Int].echo --> Int";
    is Foo[Str].echo("str"),"str","Foo[Str].echo --> Str";

    is Foo[Int].echo-list(5).WHAT, 'List[Int]',
      '--> List[Type] becomes List[Int]';

    ok Foo[Int].return-type ~~ Foo[Int], '*return  on Foo[Int]';
    is Foo[Int].first-in-list(<4 3 2 1>), 4, 'List[Type] param accepts List[Int] in Foo[Int]';

    is Foo[Int].aug-echo(5),5,"Foo[Int].aug-echo --> Int";
    is Foo[Str].aug-echo("str"),"str","Foo[Str].aug-echo --> Str";

    is Foo[Int].WHAT,Foo[Int],"Foo[Int].WHAT eq Foo[Int]";
    is Foo[Int],'Foo[Int]',"Foo[Int] as a string is Foo[Int]";

    ok Foo[Int] ~~ Foo, "Foo[Int] ~~ Foo";
    ok Foo[Int] ~~ Foo[Int],"Foo[Int] ~~ Foo[Int]";
    nok Foo ~~ Foo[Int], "Foo !~~ Foo[Int]";
    ok Foo[Int] ~~ Foo[Str],'Foo[Int] ~~ Foo[Str]';
    nok Foo[Str] ~~ Foo[Int],'Foo[Str] !~~ Foo[Str]';

    is Foo[Int].double(3), 6, 'augment Foo[int] with a method';
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

{
    class Parent[Param] {
        method *return-self { $self.chars }
    }

    class Child is Parent[Int] { }

    is Parent[Int]<one>.return-self.WHAT, 'Parent[Int]', '* return .WHAT is parent';
    ok Parent[Int]<one>.return-self ~~ Parent[Int], '* return ~~ parent type';
    is Child<two>.return-self.WHAT, 'Child', '* return .WHAT on child is child';
    ok Child<two>.return-self ~~ Child, '* return ~~ child type';
}
