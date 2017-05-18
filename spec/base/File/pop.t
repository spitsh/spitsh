use Test; plan 2;

given File.tmp {
    .write: <one two three>;
    is .pop, 'three', '.pop return value';
    is .slurp, <one two>, '.pop modified file';
}
