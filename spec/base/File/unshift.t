use Test; plan 2;

given File.tmp {
    .write: <one two three>;
    is .unshift("zero"), 'zero', '.unshift return value';
    is .slurp, <zero one two three>, '.unshift modified file';
}
