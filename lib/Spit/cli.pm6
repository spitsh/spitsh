use Spit::Compile;
use Spit::OptsParser;
need Spit::Repo;

sub get-ver {
    try $*REPO.resolve(CompUnit::DependencySpecification.new(:short-name<Spit::Compile>)).distribution.meta<ver>
}

sub USAGE is export(:MANDATORY) {
    print
    "Spook in the Shell Script compiler v{get-ver() || 'DEV'}\n" ~
    q:to/END/;
    Usage: spit [OPTIONS] COMMAND [arg...]

    Options:
       --debug             Output debugging information + timings for each compilation stage.

       --in-docker=IMAGE   Pipes script it into a docker container made from IMAGE. Docker is
                           run like: "docker run -i --rm $IMAGE sh". This automatically sets
                           the OS for you unless you specify another with --os.

       --no-inline         Turns inlining of routine calls.

       --os=debian         Which operating system to compile for.

       --opts=json         A json object where the keys are the option names and the values
                           the option values. If a value starts with '$:' the rest is evaluated
                           as a Spit expression in the context of the option's declaration.

       --target=STAGE      Sets the compilation stage to finish at:  Can be any of:
                             - parse:   A .gist of the match object from parsing the program.
                             - stage1:  A .gist of the SAST tree after parsing.
                             - stage2:  A .gist of the SAST tree after contextualisation.
                             - stage3:  A .gist of the SAST tree after composition.
                             - compile: The compiled shell script (default)

       --run               Runs the output on this computer's /bin/sh
    Commands:
       compile FILE        Compiles a file as Spit-sh e.g. spit compile src/cfg.spt
       eval SRC            Compiles a string as Spit-sh  e.g. spit eval 'say "hello world"'
    END
}

proto MAIN(
    Str $cmd,*@,
    :$in-docker is copy,
    Bool :$*debug,
    Str  :$*target = 'compile',
    Bool :$no-inline,
    :$opts,
    Int :$jobs,
    Str :$os,
    Bool :$run,
    :@*repos = [
           Spit::Repo::File.new,
           Spit::Repo::Core.new
       ]
) {
    note "run starting" if $*debug;

    my $mangle-os = do if $os {
        $os;
    } elsif $in-docker {
        if $in-docker ~~ Bool {
            $in-docker = 'debian' if $in-docker;
        } else {
            $in-docker;
        }
    };

    my %*opts = do if $mangle-os {
        parse-opts $opts,mangle => %(|(os => "-> OS<$mangle-os>"));
    } else {
        parse-opts $opts;
    };

    my ($docker,$promise) =  do if $cmd ne 'prove' and $in-docker {
        start-docker($in-docker);
    };

    my $res = try { {*} };

    if $! {
        # should kill docker here.
        note $!.gist;
        exit 1;
    }

    if $in-docker {
        write-docker $docker,$promise,$res;
    } elsif $run {
        run 'sh','-c', $res;
    } else {
        print $res;
    }
    note "run finished { now - INIT now }" if $*debug;
};

multi MAIN("eval",Str $program? is copy,*%_) {
    $program //= $*IN.slurp-rest;
    compile(
        $program,
        name => 'eval',
        |%_,
        :%*opts,
    ).gist;
}

multi MAIN("compile",Str $file,*%_) {
    do if $file.IO.e {
        compile($file.IO.slurp,name => $file,|%_,:%*opts).gist;
    } else {
        die "couldn't find '$file'";
    }
}

multi MAIN("prove",Str $path,:$jobs, :$in-docker is copy, :$run, *%_) {
    $in-docker = 'debian' unless $in-docker || $run;
    my $opt = $in-docker ?? "--in-docker=$in-docker" !! "--run";
    my @run  = "prove",("-j$_" with $jobs), '-r', '-e', "$*PROGRAM $opt compile", $path;
    note @run.perl;
    exit run(@run).status
}

sub start-docker($image is copy) {
    my @args = 'docker','run','-i','--rm',$image,'sh';
    note "starting docker with {@args[1..*].gist}" if $*debug;
    my $docker = Proc::Async.new(|@args,:w);
    ($docker,$docker.start);
}


sub write-docker($docker,$p,$shell) {
    my \before = now;
    note "writing output to docker.." if $*debug;
    $docker.write($shell.encode('utf8'));
    sleep 0.1; # RT#122722
    $docker.close-stdin;
    await $p;
    note("writing output to docker ✔ {now - before}") if $*debug;
}


sub EXPORT($main = '&MAIN') {
    Map.new: $main, &MAIN;
}
