use Test;

plan 1;

if $*os ~~ Alpine {
    skip-rest ‘alpine can't Pkg.install’;
} else {
    ok Docker.hello-world, 'hello world';
}
