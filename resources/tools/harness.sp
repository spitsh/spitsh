constant @:run = <cli base packages commands transport json ssh http-client docker helper>;
constant @:on       = <alpine centos debian>;
constant $:verbose = True;
constant $:spit = Cmd<spit>;
constant $:jobs = 0;

ok Cmd<docker>, 'docker cli is available';

ok $:spit, 'spit command exists';

${set -e};

my $d-on = "-d={@:on.join(',')}";
my @v = ('-v' if $:verbose);
my @run = \${$:spit prove @v $d-on ("-j=$_" if $:jobs) };

if @:run.first('cli') {
    ${ $:spit prove 'spec/cli' --RUN };
}

if @:run.first('base') {
    ${@run 'spec/base'};
}

if @:run.first('packages') {
    ${@run 'spec/packages'};
}

if @:run.first('transport') {
    ${@run 'spec/transport'}
}

if @:run.first('json') {
    ${@run 'spec/json'}
}

if @:run.first('ssh') {
    ${@run 'spec/ssh'}
}

# Runs all the tests in the same container
sub continue-in-container($path, :$mount-socket) {
    for @:on -> $os {
        my $container = Docker.create($os, :$mount-socket);
        $container.start-sleep;
        ${$:spit prove ('-v' if $:verbose) "-D=$container" "--os=$os" $path};
        $container.remove;
    }
}

if @:run.first('http-client') {
    continue-in-container('spec/http-client');
}


if @:run.first('docker') {
    continue-in-container('spec/docker', :mount-socket);
}

if @:run.first('helper') {
    ok ${$:spit helper build *>info}, 'helper build';
    ok DockerImg("spit-helper:$?spit-version"), 'helper exists';
}
