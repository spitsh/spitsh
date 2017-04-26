use Spit::Compile;
use Spit::OptsParser;
need Spit::Repo;

sub get-ver {
    try $*REPO.resolve(CompUnit::DependencySpecification.new(:short-name<Spit::Compile>)).distribution.meta<ver>
}

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
    Pipes script it into a docker container made from <image>.
    If <image> isn't specified 'debian' is used. The container is
    automatically removed. This automatically sets the 'os' option
    based on the image name (if it can) unless you specify another
    in --opts or --os.

  -s --mount-docker-socket
    Mounts /var/run/docker.sock into the container.

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

  --target=<stage name>
    Sets the compilation stage to finish at:  Can be any of:
      - parse:   A .gist of the match object from parsing the program.
      - stage1:  A .gist of the SAST tree after parsing.
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
      Docker images to execute the scriptsunder prove. Multiple image names
      must be comma separated.
  -j --jobs=<number>
      The number of jobs that prove should run.

Examples:
  spit prove mytest.t
  spit prove t/
  spit prove -d=centos,alpine t/
END

constant $general-usage = q:to/END/;
Spook in the Shell Script compiler v\qq[{get-ver() || 'DEV'}]

Usage: spit [COMMAND|PATH]

If the first argument contains '/' or '.' it's assumed to be a PATH and is
run with the compile command.

Commands:
  compile  Compile a file as spit code
  eval     Compile a string as spit code
  prove    Run prove(1) with test files written in spit

run 'spit COMMAND --help' for more information about a command
END


my constant %usage = %(
    eval => $eval-usage,
    compile => $compile-usage,
    general => $general-usage,
    prove   => $prove-usage,
);

my class commands {
    method compile(Str:D $file,
                   :$debug,
                   :$target,
                   :$opts,
                   :$no-inline,
                  ) {
        if $file.IO.e {
            compile($file.IO.slurp, :$debug, :$target, :$opts, :$no-inline, name => $file).gist;
        } else {
            die "no such file ‘$file’";
        }
    }

    method eval(Str:D $src, :$debug, :$target, :$opts, :$no-inline) {
        compile($src, :$debug, :$target, :$opts, :$no-inline, name => "eval").gist;
    }

    method prove(Str:D $path, Str:D $in-docker, :$jobs) {
        my @runs = $in-docker.split(',').map: { "-d=$_" };
        for @runs {
            my @run = "prove", ("-j$_" with $jobs), '-r', '-e', "$*EXECUTABLE $*PROGRAM $_ compile", $path;
            note "running: ", @run.perl;
            my $run = run @run;
            exit $run.status unless $run.status == 0;
        }
    }
}

sub do-main() is export {
    my (@pos,%named) := parse-args(@*ARGS);

    if not @pos {
        print %usage<general>
    } else {
        given @pos[0] {
            when %named<help>:exists { print %usage{$_} // %usage<general> }
            when 'compile'|'eval' {
                compile-or-eval(@pos.shift, @pos, %named)
            }
            when 'prove' {
                %named<jobs> //= %named<j>;
                my $in-docker = %named<in-docker> // %named<d>;
                $in-docker =  'debian' unless $in-docker ~~ Str:D;
                commands.prove(@pos[1], $in-docker, |%named);
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
    %named<interactive> //= %named<i>;
    %named<force-interactive> //= %named<I>;
    %named<in-docker> = 'debian' if %named<in-docker> === True;
    %named<target> //= 'compile';
    %named<mount-docker-socket> //= %named<s>;
    my $*debug = %named<debug>;

    with %named<opts> {
        $_ .= &parse-opts;
    } else {
        $_ = {};
    };
    with %named<os> {
        %named<opts><os> //= Spit::LateParse.new(
            val => "OS<$_>",
            match => (m/.*/),
        ),
    }

    with %named<interactive> {
        %named<opts><interactive> = Spit::LateParse.new(val => '$?IN.tty');
    } else {
        if %named<force-interactive> {
            %named<opts><interactive> = Spit::LateParse.new( val => 'True')
        }
    }

    my ($docker,$promise) = do with %named<in-docker> {
        if m/<!after ':'> (\w|'-')+ <!before '/'>/ {
            %named<opts><os> //= Spit::LateParse.new(
                val => "OS<$_>",
                match => $/,
            );
        }
        if %named<target> eq 'compile' {
            start-docker $_, |%named;
        }
    };

    my $res = try given $command {
        when 'compile' {
            commands.compile(@pos[0], |%named);
        }
        when 'eval' {
            commands.eval(@pos[0],|%named);
        }
    };

    if $! {
        # should kill docker here.
        note $!.gist;
        exit 1;
    }

    if $docker {
        write-docker $docker,$promise,$res;
    } elsif %named<RUN> {
        exit (run 'sh','-c', $res).status;
    } else {
        print $res;
    }
}

constant $docker-socket = '/var/run/docker.sock';

sub start-docker($image is copy, :$mount-docker-socket, *%) {
    my $mount := do if $mount-docker-socket {
        $docker-socket.IO.e or
            die "can't find $docker-socket to mount inside container";

        ('-v', "$docker-socket:$docker-socket");
    };

    my @args = 'docker','run',|$mount,'-i','--rm',$image,'sh';
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
