constant $docker-socket-path = '/var/run/docker.sock';

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

sub docker-image-exists($name) is export {
    run('docker', 'image', 'inspect', $name,:!out).exitcode == 0;
}

sub start-docker($image is copy, :$docker-socket, *%) is export {
    my $mount := do if $docker-socket {
        $docker-socket-path.IO.e or
            die "can't find $docker-socket to mount inside container";

        ('-v', "$docker-socket-path:$docker-socket-path");
    };

    # SEE: https://gist.github.com/LLFourn/70b70b7e26b5e57de7894eefee3c97e1
    # For an explanation of this:
    my @args = 'docker','run',|$mount,'-i','--rm',$image,'sh', '-c',
      ‘mkfifo stdin; trap 'kill $!; wait $!' TERM; trap 'rm stdin' EXIT; sh<stdin & cat>stdin; wait $!’;
    note "starting docker with {@args[1..*].gist}" if $*debug;
    my $docker = Proc::Async.new(|@args, :w);
    cleanup-containers();
    @containers.push($docker);
    my $p = $docker.start;

    ($docker, $p);
}

sub exec-docker($container, *%) is export {
    my @args = 'docker', 'exec', '-i', $container, 'sh';
    note "starting docker with {@args[1..*].gist}" if $*debug;
    my $docker = Proc::Async.new(|@args, :w);
    my $p := $docker.start;
    ($docker, $p);
}

sub write-docker($docker,$p,$shell) is export {
    my \before = now;
    note "writing output to docker.." if $*debug;
    await $docker.write($shell.encode('utf8'));
    $docker.close-stdin;
    my $proc = await $p;
    note("writing output to docker ✔ {now - before}") if $*debug;
    $proc;
}
