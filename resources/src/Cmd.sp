#| Cmd represents a name or path of a command in the shell.
augment Cmd {
    #| Returns true if the command can be found in the current shell enironment.
    #|{ my Bool $have-node = Cmd<node>.exists }
    method exists? ${command -v $self >X}

    #| Cmd returns `.exists` in Bool context
    #|{
        if Cmd<curl> || Cmd<wget> -> $ua {
            say "$ua is here, it can be our http user agent";
        }
    }
    method Bool { $self.exists }

    method install? {
        -->Pkg.install unless $self;
    }

    method ensure-install-->Cmd {
        -->Pkg.install unless $self;
        $self;
    }

    method path-->File on {
        RHEL   ${whereis -b $self | awk '{print $2}'}
        Debian ${whereis -b $self | awk '{print $2}'}
        Any ${ command -v $self }
    }


}
