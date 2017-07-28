need Spit::SAST;
need Spit::Exceptions;
use Spit::Metamodel;
use Spit::Sh::ShellElement;
unit role Compile-Cmd-And-Call;

has $.max-chars-per-line = 80;

method pipe-input(
    $input,
    # $here-doc is rw,
    # :$in-pipe, # True unless this is|the|last← thing in pipe
)
{
    if $input andthen
    # If the method body we're in is already having its $self piped
    # then the pipe is implicit and we don't need to do anything.
    !($input.is-self andthen .piped)
    {
        if self.try-heredoc($input) -> ($delim, $body) {
            # Our input can be heredoc'd with cat.
            # Note: You might think that you should be able to do this without
            # cat by just <<- into the first command in the pipe.
            # I attempted this and it as extremely difficult in complex
            "cat <<-'$delim' | ", |$body;
        } else {
            |self.cap-stdout($input), '|';
        }
    }
}

method call($name, @named-param-pairs, @pos, :$slurpy-start) {
    |@named-param-pairs.\ # Errr rakudo, why do I need \ here?
       grep({.value.compile-time !=== False }).\
       map({ self.gen-name(.key),"=",|self.arg(.value),' '} ).flat,
    $name,
    |flat @pos.kv.map: -> $i, $_ {
        ' ',
        |($slurpy-start.defined && $i >= $slurpy-start
            ?? self.arg($_).itemize(.itemize)
            !! self.arg($_)
         )
    }
}

#!Call
multi method node(SAST::Call:D $_)  {
    |self.call(
        self.gen-name(.declaration),
        .param-arg-pairs,
        .pos,
        slurpy-start => (.declaration.signature.slurpy-param andthen .ord)
    ),
    |(.null andthen ' >&',|self.arg($_))
}

multi method assign($var,SAST::Call:D $call) {
    if $call.declaration.return-by-var {
        |self.node($call),'; ',self.gen-name($var),'=$R';
    } else {
        nextsame;
    }
}

multi method node(SAST::MethodCall:D $_, :$tight) {
    my $call;
    my $slurpy-start = (.declaration.signature.slurpy-param andthen .ord);
    my $pipe;
    if .declaration.invocant andthen .piped {
        $pipe := self.pipe-input(.invocant);
        $call :=   |$pipe,
                   |self.call(
                       self.gen-name(.declaration),
                       .param-arg-pairs,
                       .pos,
                       :$slurpy-start
                   );
    } else {
        $call := |self.call:
                   self.gen-name(.declaration),
                   .param-arg-pairs,
                   ((.declaration.static ?? Empty !! .invocant ), |.pos),
                   slurpy-start => (.declaration.static
                                      ?? $slurpy-start + 1
                                      !! $slurpy-start)
    }

    if .declaration.rw and .invocant.assignable {
        |self.gen-name(.invocant),'=$(',|$call,')';
    } else {
        ('{ ' if $pipe and $tight),
        |$call, |(.null andthen ' >&',|self.arg($_)),
        (';}' if $pipe and $tight)
    }
}

multi method arg(SAST::Call:D $_) is default {
    SX::Sh::ReturnByVarCallAsArg.new(call-name => .name,node => $_).throw
        if .declaration.return-by-var;
    nextsame;
}

multi method cap-stdout(SAST::Call:D $_,|c) is default {
    nextsame if .original-type ~~ tBool;
    self.node($_,|c)
}

#!Cmd
multi method node(SAST::Cmd:D $cmd, :$tight) {
    if $cmd.nodes == 0 {
        my @cmd-body = self.cap-stdout($cmd.pipe-in);
        self.compile-redirection(@cmd-body,$cmd);
    } else {
        my @in = $cmd.in;
        my @cmd-body  = |self.arglist($cmd.nodes);
        my $full-cmd := |self.compile-redirection(@cmd-body,$cmd);

        my $pipe := self.pipe-input($cmd.pipe-in);
        |$pipe,
        # Make a newline if the pipe looks too long
        ("\\\n$*pad  " if $pipe.substr($pipe.rindex("\n") // 0).chars > $!max-chars-per-line),
        |$cmd.set-env.map({"{.key.subst('-','_',:g)}=",|self.arg(.value)," "}).flat,
        |$full-cmd;
    }
}

method compile-redirection(@cmd-body, $cmd) {
    my @redir;
    my $eval;

    my @redirs := 1,'>' ,$cmd.write,
                  1,'>>',$cmd.append,
                  0,«<» ,$cmd.in;

    for @redirs -> $default-lhs, $sym, @list {
        for @list -> $lhs,$rhs {
            my $lhs-ct := $lhs.compile-time;
            # FIXME: Empty isn't a valid FD. It should not get here if it's Empty.
            next if $rhs.compile-time ~~ Empty;
            $eval = True without $lhs-ct;
            @redir.push: list ($lhs-ct ~~ $default-lhs ?? '' !! self.arg($lhs));
            @redir.push($sym);
            @redir.push: list ('&' if $rhs.type ~~ tFD),
                              ($rhs.compile-time ~~ -1 ?? '-' !! |self.arg($rhs));
        }
    }

    with $cmd.null { @redir.push: '', '>&', self.arg($_) }

    if $eval {
        'eval ',escape(|@cmd-body," "),
        |@redir.map(-> $in,$sym,$out { |$in,escape($sym, $out.flat) }).flat;
    } else {
        |@cmd-body,|(@redir.map(-> $a,$b,$c {' ',|$a,|$b,|$c}).flat if @redir) ;
    }
}


multi method cap-stdout(SAST::Cmd:D $_) {
    nextsame if .original-type ~~ tBool;
    self.node($_);
}
