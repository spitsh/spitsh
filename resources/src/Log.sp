my FD $:LOG = $:ERR;
constant $:log-level = 1;
constant $:log = False;
constant $:log-default-path = "\c[GHOST]";
my @:log-levels  = (
    none => '',
    debug => "\c[WHITE QUESTION MARK ORNAMENT]",
    info  => "\c[INFORMATION SOURCE, VARIATION SELECTOR-16] ",
    warn => "\c[WARNING SIGN]",
    error => "\c[HEAVY EXCLAMATION MARK SYMBOL]",
    fatal => "\c[SKULL AND CROSSBONES]",
);

constant $:log-fatal-level = 5;

constant $:log-date-format = '%b %d %T';

class Log {
    method date~ {
        $self.${ cut -s '-d|' '-f1' }
    }
    method level-sym~ {
        $self.${cut -s '-d|' '-f2'};
    }
    method level-name~ {
        @:log-levels.key-for($self.level-sym);
    }
    method level+ {
        @:log-levels.values.pairs.key-for($self.level-sym);
    }
    method path~ {
        $self.${ cut -s '-d|' '-f3' }
    }
    method message~ {
        $self.${ cut -s '-d|' '-f4-' }
    }
}

# While logging is a WIP we'll just leave this here
augment Str {

    method log(Int $level, $path?) {
        if $:log and $level >= $:log-level {
            my $_path = $path || $:log-default-path;
            on {
                BusyBox {
                    $self.${
                        awk > $:LOG
                        -v "level_sym={@:log-levels[$level].value}"
                        -v "level=$level"
                        -v "path=$_path"
                        -v "pid=$?PID"
                        -v "date_format=$:log-date-format"
                        -v "fatal_level=$:log-fatal-level"
                        Q⟪
                            length() == 0 { next }
                            {
                                if ($0 ~ /^([^|]+\|){3}/) {
                                    print gensub(/^(([^|]+\|){2})([^|]+\|)/, "\\1"path"/\\3",1)
                                } else {
                                    "date '+"date_format"'" | getline date;
                                    printf "%s|%s|%s|%s\n",date,level_sym,path,$0;
                                }
                                if(level >= fatal_level)
                                    die = 1
                            }
                            END { if(die){ system("kill "pid) } }⟫
                    }
                }
                GNU {
                    $self.${
                        sed -ru > $:LOG
                        -e (
                            # if it looks like a log append its path to this one
                            # print and then branch to the end
                            ‘s§^(([^|]+\|){2})([^|]+\|)§\1’ ~ $_path ~ ‘/\3§;t;’ ~
                            # remove empty lines
                            '/^$/d;' ~
                            # Put the path on the front of the message
                            "s§^§$_path|§;" ~
                            # Put everything in hold space and put the date in pattern space
                            “h;s/.*/date '+$:log-date-format'/e;” ~
                            # Append the hold space to the date and add the
                            # insert the log level symbol between the two
                            ‘G;s§\n§|’ ~ @:log-levels[$level].value ~ ‘|§;’ ~
                            # Add a newline if it doesn't exist
                            ("\$e kill $?PID" if $level == $:log-fatal-level)
                        )
                        -e '$a\\'
                    }
                }
            }
        }
        else {
            #XXX: hack to stop broken pipe errors when .log is piped to when $:log
            # is False
            ${ cat >X };
        }
    }
}

sub fatal($msg, $path?){ $:log ?? $msg.log(5, $path) !! die $msg  }
sub error($msg, $path?){ $:log ?? $msg.log(4, $path) !! note $msg }
sub warn ($msg, $path?){ $:log ?? $msg.log(3, $path) !! note $msg }
sub info ($msg, $path?){ $:log ?? $msg.log(2, $path) !! note $msg }
sub debug($msg, $path?){ $:log ?? $msg.log(1, $path) !! () }

sub log-fifo(Int $level, $path?) --> File {
    my $log-fifo = File.tmp-fifo;
    # We don't really want to have to .cleanup. But if we don't and we
    # do a fatal log then the parent process will terminate and
    # therefore never reap this process. I wonder if there's a better
    # way to do it...
    (start {
        ${cat < $log-fifo}.log($level, $path);
        $log-fifo.remove;
    }).cleanup;
    $log-fifo;
}
