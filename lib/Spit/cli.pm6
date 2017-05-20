use Spit::Compile;
use Spit::OptsParser;
use Spit::Util :spit-version;
need Spit::Repo;

sub parse-args(@args) {
    my (@pos,%named);
    for @args {
        when s/^'--'// {
            if m/([\w|'-']+)['='(.*)]?/ {
                %named{$/[0].Str} = ( ($/[1] andthen .Str) || True);
            } else {
                die "badly formatted option";
            }
        }
        when s/^'-'// {
            when /(<[a..zA..Z]>)'='(.*)/ {
                %named{$/[0].Str} = $/[1].Str;
            }
            when /(<[a..zA..Z]>)+/ {
                %named{$_} = True for $/[0];
            }
            default {
                die "invalidly formatted option $_";
            }
        }
        default { @pos.push($_) }
    }

    @pos,%named;
}

constant $compile-options = q:to/END/;
Options:
  --debug
    Output debugging information + timings for each compilation stage.

  -d --in-docker[=<image>]
    Pipes script into a docker container derived from <image>. This
    automatically sets the 'os' option based on the image name (if it can)
    unless you specify another in --opts or --os. The container is removed
    after execution.

  -D --in-container=<id>
    Runs the script in an already running docker container by execing
    A new `/bin/sh` process inside it.

  -h --in-helper
    Runs the script in the spit-helper image.

  -i --interactive
    Compile a script where $*interactive will be set to whether STDIN is
    a tty. Short for --opts='{ "interactive" : ": $?IN.tty" }'.

  -I --force-interactive
    Compile a script where $*ineractive will be set to True. Short for
    --opts='{ "interactive" : true }'

  --no-inline
    Turns inlining off for routine calls.

  -o --opts=<json>
    A json object where the keys are the option names and the values
    the option values. If a value starts with ':' the rest is evaluated
    as a Spit expression in the context of the option's declaration.

  --os=<os name> (default: debian)
    Shortcut for --opts='{ "os" : ": OS<debian>" }'

  -s --mount-docker-socket
    Mounts /var/run/docker.sock into the container.

  --target=<stage name>
    Sets the compilation stage to finish at:  Can be any of:
      - parse:   A .gist of the match object from parsing the program.
      - stage1:  A .gist of the SAST tree after parsing (BROKEN)
      - stage2:  A .gist of the SAST tree after contextualisation.
      - stage3:  A .gist of the SAST tree after composition.
      - compile: The compiled shell script (default)

  --RUN
    Runs the output on this computer's /bin/sh. # Be careful :^)
END

constant $eval-usage = q:to/END/;
Usage: spit eval PROGRAM [OPTIONS]

Evaluate PROGRAM as spit code

\qq[$compile-options]

Examples:
  spit eval 'say "hello world"'
  # compile and run in docker
  spit eval -d 'say "hello world"'
  spit eval -d=centos 'say $*os.name'
  # compile for alpine
  spit eval --os=alpine 'say $*os.name'
END

constant $compile-usage = q:to/END/;
Usage: spit compile FILE [OPTIOS]

Compiles FILE as spit code

\qq[$compile-options]

Examples:
  spit compile my_program.spt
  # compile and run in docker
  spit compile -d my_program.spt
  spit compile -d=centos my_program.spt
  # compile for alpine
  spit compile --os=alpine my_program.spt
END

constant $prove-usage = q:to/END/;
Usage: spit prove PATH [OPTIONS]

Compiles and executes spit test files in docker containers under prove.
This command is just quick way of writing something like:

   for os in debian centos; do
       prove -r -e "spit -d=$os compile" spec/base/sanity.t || exit 1;
   done

   Which is similar to running:

   spit prove spec/base/sanity.t -d=debian,centos

Options:
  -d --in-docker=<image list>
    Docker images to derive containers from to execute the scripts under
    prove. Multiple image names must be comma separated. If the image name
    matches an OS then --os will automatically be set.

  -D --in-container=<id list>
    Docker containers to execute the scripts under prove using `docker exec`.
    Multiple container ids must be comma separated. The containers must
    already be running.

  -j --jobs=<number>
    The number of jobs that prove should run.

  --os=<os name>
    Pass --os to the underlying `spit compile`

  -s --mount-docker-socket
    Mounts /var/run/docker.sock inside the containers.

  -v --verbose
    Pass --verbose to the underlying prove(1) command.

Examples:
  spit prove mytest.t
  spit prove t/
  spit prove -d=centos,alpine t/
END

constant $helper-usage = q:to/END/;
Usage: spit helper [build|clean]

Builds, removes or upgrades the spit-helper docker image. spit-helper
is a small docker image pre-built with useful utilties for deploying
shell scripts.

Sub-commands:
  build    builds the latest spit-helper

  remove   removes the spit-helper image
           (--force uses 'docker rmi -f')

  upgrade  removes an old spit-helper image
END

constant $general-usage = q:to/END/;
Spook in the Shell compiler v\qq[{spit-version}]

Usage: spit [COMMAND|PATH]

If the first argument contains '/' or '.' it's assumed to be a PATH and is
run with the compile command.

Options:
  --help     Print this help message
  --version  Print version by itself

Commands:
  compile  Compile a file as spit code
  eval     Compile a string as spit code
  prove    Run prove(1) with test files written in spit
  helper   build/remove/update the spit-helper image

run 'spit COMMAND --help' for more information about a command
END

my constant %usage = %(
    eval => $eval-usage,
    compile => $compile-usage,
    general => $general-usage,
    prove   => $prove-usage,
    helper  => $helper-usage,
);

my constant $helper-image = "spit-helper:{spit-version}";

my class commands {
    method compile(Str:D $file,
                   :$debug,
                   :$target,
                   :$opts,
                   :$no-inline,
                  ) {
        compile(($file.IO.slurp orelse .throw), :$debug, :$target, :$opts, :$no-inline, name => $file).gist;
    }

    method eval(Str:D $src, :$debug, :$target, :$opts, :$no-inline) {
        compile($src, :$debug, :$target, :$opts, :$no-inline, name => "eval").gist;
    }

    method prove(Str:D $path, :$in-docker, :$in-container,
                 :$mount-docker-socket, :$jobs, :$os, :$opts,
                 :$verbose
                ) {

        my @runs = |($in-docker andthen .split(',').map: { "-d=$_" }),
                   |($in-container andthen .split(',').map({"-D=$_"}));

        for @runs {
            my @run =
            "prove", ("-j$_" with $jobs),('-v' if $verbose),'-r', '-e',
            "$*EXECUTABLE $*PROGRAM $_ " ~
              ("--os=$os " if $os) ~
              ("--opts=$opts " if $opts) ~
              "compile{' -s' if $mount-docker-socket}",
            $path;
            note "running: ", @run.perl;
            my $run = run @run;
            exit $run.exitcode unless $run.exitcode == 0;
        }
    }

    method helper($_) {
        when 'build' {
            my ($helper-builder, $p) = start-docker('alpine', :mount-docker-socket);
            my $build-helper-src =  %?RESOURCES<tools/spit-helper.spt>.absolute.IO;
            my $compile = compile(
                $build-helper-src.slurp,
                name => $build-helper-src,
                opts => {
                    os => late-parse('Alpine'),
                }
            );
            write-docker($helper-builder, $p, $compile);
        }
        when 'remove' {
            exit (run 'docker', 'rmi', $helper-image).exitcode;
        }
        default {
            fail-print-usage('helper');
        }
    }
}

sub fail-print-usage($section = "general") {
    note %usage{$section}; exit 1;
}

sub do-main() is export {
    my (@pos,%named) := parse-args(@*ARGS);

    if %named<version>:exists { say spit-version(); exit(0) }

    if not @pos {
        fail-print-usage;
    } else {
        given @pos[0] {
            when %named<help>:exists { print %usage{$_} // %usage<general> }
            when 'compile'|'eval' {
                @pos[1]:exists or fail-print-usage($_);
                compile-or-eval(@pos.shift, @pos, %named)
            }
            when 'prove' {
                @pos[1]:exists or fail-print-usage($_);
                %named<opts> //= %named<o>;
                %named<jobs> //= %named<j>;
                %named<mount-docker-socket> //= %named<s>;
                %named<verbose> //= %named<v>;
                my $in-docker = %named<in-docker> // %named<d>;
                my $in-container = %named<in-container> // %named<D>;
                $in-docker =  'debian' unless ($in-docker|$in-container) ~~ Str:D;
                commands.prove(@pos[1], :$in-docker, :$in-container, |%named);
            }
            when 'helper' {
                commands.helper(@pos[1]);
            }
            when *.contains(<. />.any) {
                compile-or-eval('compile', @pos, %named);
            }
            default { note %usage<general> }
        }
    }
}

sub compile-or-eval($command, @pos, %named) {
    my @*repos = [
        Spit::Repo::File.new,
        Spit::Repo::Core.new
    ];
    %named<opts> //= %named<o>;
    %named<in-docker> //= %named<d>;
    %named<in-container> //= %named<D>;
    %named<in-helper> //= %named<h>;
    %named<interactive> //= %named<i>;
    %named<force-interactive> //= %named<I>;
    %named<in-docker> = 'debian' if %named<in-docker> === True;
    %named<target> //= 'compile';
    %named<mount-docker-socket> //= %named<s> //= %named<in-helper>;
    my $*debug = %named<debug>;

    with %named<opts> {
        $_ .= &parse-opts;
    } else {
        $_ = {};
    };
    with %named<os> {
        %named<opts><os> //= late-parse("OS<$_>")
    }

    with %named<interactive> {
        %named<opts><interactive> = late-parse('$?IN.tty');
    } else {
        if %named<force-interactive> {
            %named<opts><interactive> = late-parse('True');
        }
    }

    my ($docker,$promise) = do
    with %named<in-docker> {
        if m/<!after ':'> [\w|'-']+ <!before '/'>/ -> $os {
            %named<opts><os> //= Spit::LateParse.new(
                val => "OS<$os>",
                match => $/,
            );
        }
        if %named<target> eq 'compile' {
            start-docker $_, |%named;
        }
    }
    orwith %named<in-container> {

        if %named<target> eq 'compile' {
            exec-docker $_, |%named;
        }
    }
    orwith %named<in-helper> {
        %named<opts><os> = Spit::LateParse.new(val => 'OS<spit-helper>');
        start-docker $helper-image, :mount-docker-socket, |%named;
    }

    my $res = try given $command {
        when 'compile' {
            commands.compile(@pos[0], |%named);
        }
        when 'eval' {
            commands.eval(@pos[0],|%named);
        }
    };

    if $! {
        .kill(SIGTERM) with $docker;
        note $!.gist;
        exit 1;
    }

    if $docker {
        exit (write-docker $docker,$promise,$res).exitcode;
    } elsif %named<RUN> {
        exit (run 'sh','-c', $res).exitcode;
    } else {
        print $res;
    }
}

constant $docker-socket = '/var/run/docker.sock';

my @containers;

sub cleanup-containers {
    once do {
        signal(SIGINT,SIGTERM).tap: {
            note "$_ recieved killing container";
            .kill(SIGTERM) for @containers;
            exit(0);
        }
    }
}

sub start-docker($image is copy, :$mount-docker-socket, *%) {
    my $mount := do if $mount-docker-socket {
        $docker-socket.IO.e or
            die "can't find $docker-socket to mount inside container";

        ('-v', "$docker-socket:$docker-socket");
    };

    # XXX: Docker runs things as PID 1. This is bad for shell scripts because
    # you can't TERM signals to PID 1. So we do 'sh -c sh' to get a child PID.
    # :;sh is a trick to get bash to start a new process.
    my @args = 'docker','run',|$mount,'-i','--rm',$image,'sh', '-c', ':;sh';
    note "starting docker with {@args[1..*].gist}" if $*debug;
    my $docker = Proc::Async.new(|@args, :w);
    cleanup-containers();
    @containers.push($docker);
    my $p = $docker.start;

    ($docker, $p);
}

sub exec-docker($container, *%) {
    my @args = 'docker', 'exec', '-i', $container, 'sh', '-c', ':;sh';
    note "starting docker with {@args[1..*].gist}" if $*debug;
    my $docker = Proc::Async.new(|@args, :w);
    my $p := $docker.start;
    ($docker, $p);
}

sub write-docker($docker,$p,$shell) {
    my \before = now;
    note "writing output to docker.." if $*debug;
    $docker.write($shell.encode('utf8'));
    sleep 0.1; # RT#122722
    $docker.close-stdin;
    my $proc = await $p;
    note("writing output to docker ✔ {now - before}") if $*debug;
    $proc;
}
