augment Host {

    method connectable(Port $port, Int :$timeout = 1)? on {
        Alpine {
            ${nc $self $port -w $timeout -z >X}
        }
        GNU {
            ${timeout $timeout bash -c "true >/dev/tcp/$self/$port" !>X}
        }
    }

    static method local^ { 'localhost' }

    method wait-connectable(Port $port, Int :$timeout = 60)? {
        debug "Waiting for $self to open port $port (timeout:$timeout)";
        my $start = now.posix;
        my $connected = False;
        while now.posix < ($start + $timeout) and !$connected {
            $connected = $self.connectable($port);
            sleep 1;
        }
        $connected;
    }

    method read-port(Int $port)~ {
        ${ $:socat !>warn -u "TCP:$self:$port" -}
    }

    method write-port(Int $port, $message)~ {
        $message.${ $:socat !>warn - "TCP:$self:$port"}
    }

    method ssh(
        $shell,
        :$user = 'root',
        :$port = 22,
        :$identity = $:ssh-identity-file,
        :@options,
        :@host-key-algorithms,
        Bool :$debug
    )~
    {
        my $ssh-host = "$user@$self";
        debug "Attempting ssh to $ssh-host:$port";
        # XXX: Until we figure out how to make the ssh connection wait
        # for logging to finish
        “trap 'sleep 1; exit 1' TERM; $shell”.${
            $:ssh !>warn($ssh-host)
            ("-i$_" if $identity)
            ('-vvv' if $debug)
            -p $port
            ("-o$_" for @options)
            ("-oHostKeyAlgorithms=" ~ .join if @host-key-algorithms)
            "$ssh-host" sh
        }
    }

    method ssh-keyscan(:$port = 22, :$type = 'rsa,ecdsa,ed25519', Bool :$debug) -->List[SSH-known-host]
    ${
        $:ssh-keyscan !>debug
        ('-v' if $debug)
        -p $port
        -t $type
        $self
    }

}
