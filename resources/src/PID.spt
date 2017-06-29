sub kill(PID *@pids, :$signal = 'TERM') {
    ${kill "-$signal" @pids} if @pids;
}

sub wait(PID *@pids) {
    ${wait @pids}
}

constant File $?pid-cleanup = ${mktemp};

#| The PID class represents an integer process ID.
augment PID {
    #| In Bool context the PID returns the result of `.exists`
    method Bool { $self.exists }
    #| Returns true if the process exists on the system.
    method exists? on {
        Alpine ${ps -o 'pid' | awk -v "p=$self" '$1==p{f=1}END{exit !f}'}
        Debian { File("/proc/$self").exists }
        Any    ${ps -p $self >X}
    }
    #| Sends the process a signal. Returns true if the signal was successfully
    #| sent.
    method kill($signal = 'TERM')? {
        ${kill "-$signal" $self !>X};
    }

    method kill-group($signal = 'TERM')?{
        ${kill $signal "-$self"}
    }

    static method list -->List[PID] ${
        find '/proc' -maxdepth 1 -name '[0-9]*' -printf '%f\n'
    }

    method children -->List[PID] on {
        # Debian is a special snowflake since in stretch ps(1) is no
        # longer in an "essential" package (!?) so doesn't get included in the
        # docker image.
        # see: https://github.com/debuerreotype/debuerreotype/issues/14
        Debian {
            for PID.list {
                # Print the pid if its PPid in /proc/pid/status is eq $self
                ${
                    awk -v "p=$_" -v "s=$self" !>X
                    '/PPid:/ && $2 == s { print p }'
                    "/proc/$_/status"
                }
            }
        }
        Any ${ps -o 'ppid,pid' | awk -v "p=$self" '$1==p{print $2}'}
    }

    method descendants-->List[PID] {
        $_, .descendants for $self.children;
    }

    method cleanup^ {
        $?pid-cleanup.push($self)-->PID;
        FILE-CLEAN {
            ${kill @($?pid-cleanup.slurp) !>X};
            $?pid-cleanup.remove;
        }
    }

    method wait? ${wait $self}
}

augment List[PID] {
    method wait { wait @$self }
    method kill($signal = 'TERM') { kill :$signal, @$self }
}
