use Test; plan 2;

given File.tmp {
    .write: <one two three>;
    is .shift, 'one', '.shift return value';
    is .slurp, <two three>, '.shift modified file';
}
