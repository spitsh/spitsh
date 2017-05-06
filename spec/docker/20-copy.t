use Test;

plan 3;

my $copy-test = Docker.create("alpine", :name<spit_copy_test>);

my File $tmp .= tmp;

$tmp.write("some content");

$copy-test.copy($tmp, '/foo.txt');

ok $copy-test.exec( eval{ ?File</foo.txt> } ),
    'copied file exists';

ok $copy-test.exec( eval{ File</foo.txt>.slurp eq 'some content' } ),
    'copied file has the right content';

nok $copy-test.exec( eval{ File</foo.txt>.slurp eq 'snome conzent' } ),
    ‘exec isn't just telling us what we want to hear’;

$copy-test.remove;
