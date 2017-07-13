class Docker { }
class DockerImg { }

constant File $:docker-socket = '/var/run/docker.sock';
constant File $:docker-install-cli-path = '/usr/local/bin/docker';

constant Cmd $:docker is logged-as("\c[WHALE]") = on {
    Spit-Helper { 'docker' }
    Linux {
        Cmd<docker> or (
            if $:docker-socket {
                debug "$_ exists so only installing docker cli";
                Docker.install-cli;
            } else {
                debug "$_ doesn't exist so installing the full Docker package";
                Docker.install;
                'docker';
            }
        )
    }
}

constant $:moby-github = GitHubRepo<moby/moby>;

constant File $?docker-cleanup = ${mktemp};
constant File $?docker-img-cleanup = ${mktemp};

augment Docker {

    static method latest-build-ver~ {
        my $gh-release-url = $:moby-github.latest-release-url;
        die "unable to get latest docker version" unless $gh-release-url;
        $gh-release-url.${sed 's/.*\/v//'};
    }

    static method latest-build-tgz-url-->HTTP {
        my $latest-v = Docker.latest-build-ver;
        "https://download.docker.com/linux/static/stable/x86_64/docker-{$latest-v}.tgz";
    }
    static method install-cli-->File {
        my $url = Docker.latest-build-tgz-url;
        info "Getting latest docker build from $url";
        my $docker-dir = $url.get.extract.cleanup;
        info "Installing to $:docker-install-cli-path";
        $docker-dir.add('docker').move-to($:docker-install-cli-path);
        $:docker-install-cli-path;
    }

    static method install {
        info 'running https://get.docker.com script';
        ${
            sh -c (HTTP<https://get.docker.com>.get)
            >debug('docker-install.sh')
            !>debug('docker-install.sh')
        };
    }

    static method hello-world? {
        ${ $:docker run -i --rm hello-world *>debug('hello-world') };
    }

    method cleanup -->Docker {
        $?docker-cleanup.push($self);
        END {
            $?docker-cleanup.slurp-->List[Docker].remove;
            $?docker-cleanup.remove;
        }
    }

    static method create(
        $from,
        :$name,
        :@args,
        Bool :$mount-socket
    ) -->Docker {
        my $id = ${
            $:docker create -i !>error
            ("--name=$_" if $name)
            ("-v=$:docker-socket:$:docker-socket" if $mount-socket)
            --entrypoint ''
            @args $from sh -c ':;sh'
        }.substr(0,12); # 12 is a sufficient length of hash
        $name || $id;
    }

    method exists? ${ $:docker container inspect $self *>X }
    method Bool    { $self.exists }

    method copy($from, File $to) -->File {
        ${ $:docker cp $from "$self:$to" !>error};
        $to.add($from);
    }

    method copy-from($from,$to) --> File {
        ${ $:docker cp "$self:$from" $to !>error};
        $to;
    }

    method remove? { $self-->List[Docker].remove }

    method running? {
        ${ $:docker inspect -f '{{.State.Status}}' $self } eq 'running';
    }

    method start-sleep {
        debug "Starting docker container $self with sleep";
        'while true; do sleep 1; done'.${ $:docker start $self >X !>error};
    }

    method exec(Str $eval)? {
        if $self.running {
            $eval.${ $:docker exec -i $self sh >debug/warn($self) };
        } else {
            $eval.${ $:docker start >debug/warn($self) -i $self };
        }
    }

    method commit(
DockerImg :$name,
          :$tag,
          :@cmd,
          :$env,
          :@entrypoint,
          :$expose,
     Pair :@labels,
          :$onbuild,
          :$user,
          :$volume,
          :$workdir,
     Bool :$remove-old
    )-->DockerImg {
        if $remove-old and $name.exists {
            info "Removing previously existing $name";
            $name.remove;
        }

        my @args = \${
            ("-c=CMD " ~ .JSON if @cmd )
            ("-c=ENV $_" if $env )
            ("-c=ENTRYPOINT " ~ .JSON if @entrypoint)
            ("-c=EXPOSE $_" if $expose)
            ("-c=USER $_" if $user)
            ("-c=VOLUME $_" if $volume)
            ("-c=WORKDIR $_" if $workdir)
            (if @labels {
                '-c=LABEL ' ~ (“{.key}="{.value}"” for @labels).join(" ")
            })
            $self
            @$name
        };

        debug "docker commit: ‘{@args.join('’, ‘')}’";
        my $image = ${$:docker commit  !>fatal @args |
                      sed -r 's/^sha256:(.{12}).*/\1/'};
        $name || $image;
    }
}

augment DockerImg {
    method exists? { ~$self and ${ $:docker image inspect $self *>X } }
    method remove? { $self-->List[DockerImg].remove }
    method Bool { $self.exists }

    method cleanup^ {
        $?docker-img-cleanup.push: $self;
        END {
            $?docker-img-cleanup.slurp-->List[DockerImg].remove;
            $?docker-cleanup.remove;
        }
    }
    method add-tag ($tag)^ {
        my $tagged-name = $tag.contains(':') ?? $tag !! "{$self.name}:$tag";
        debug "Tagging $self with $tagged-name";
        ${$:docker tag $self $tagged-name !>fatal} ?? $tagged-name !! ()
    }

    method name~ {
        $self.${sed -r 's/(.*):.*/\1/'}
    }

    method tag~ {
        $self.${sed 's/.*://;t;s/.*/latest/' }
    }

    method id -->DockerImg ${ $:docker image inspect $self '-f={{.Id}}' !>error }

    method tags -->List[DockerImg] ${
        $:docker image inspect $self
        ｢-f={{range $i, $e := .RepoTags}}{{if $i}}{{"\n"}}{{end}}{{$e}}{{end}}｣
    }

    method copy-from($from,$to) -->File {
        debug "copying $from in $self to $to";
        my $tmp = Docker.create($self);
        $tmp.copy-from($from,$to);
        ${ $:docker rm -f $tmp >X};
        $to;
    }

    method labels --> List[Pair] {
        ${$:docker image inspect
          '-f={{range $key, $value := .Config.Labels}}{{print $key "\t" $value "\n"}}{{end}}'
          $self
         }
    }

    static method images(
        :@has-labels,
        Pair :@labels,
        Bool :$dangling,
        :$reference
    ) --> List[DockerImg] ${
            $:docker images -qa
            ("-f=label={.key}={.value}" for @labels)
            ("-f=label=$_" for @has-labels)
            ("-f=dangling=true" if $dangling)
            ("-f=reference=$_" if $reference)
            | uniq # docker images can return duplicates
    }
}

augment List[Docker] {
    method remove? {
        debug "Removing containers: {$self.join(',')}" if $self;
        ${ $:docker rm -f @$self *>X }
    }
}

augment List[DockerImg] {
    method remove? {
        if $self {
            debug "Removing images: {$self.join(',')}";
            ${ $:docker rmi -f @$self >debug/warn };
        }
    }
}
