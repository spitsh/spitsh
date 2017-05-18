use Test; plan 2;

{
    given File.tmp {
        .write(<one two three four five six seven eight nine>);
        is .grep(/i.{1,2}$/), <five six nine>, '.grep';
        is .first(/i.{1,2}$/), <five>, '.first';
    }
}
