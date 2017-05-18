use Test; plan 2;

given File.tmp {
    .write: <X.one two X.three four>;
    is .remove-lines(/^X\./), <X.one X.three>, '.remove-lines returns right value';
    is .slurp, <two four>, '.remove lines removed the right lines';
}
