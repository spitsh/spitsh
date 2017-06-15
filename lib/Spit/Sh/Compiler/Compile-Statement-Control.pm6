need Spit::SAST;
need Spit::Exceptions;
use Spit::Metamodel;
use Spit::Sh::ShellElement;

unit role Compile-Statement-Control;

#!If
multi method node(SAST::If:D $_, :$else) {
    ($else ?? 'elif' !! 'if'),' ',
    |self.compile-topic(
        .topic-var,
        (.cond, .then, (.else if .else ~~ SAST::Stmts))
    ),
    |self.cond(.cond),"; then\n",
    |self.node(.then,:indent,:no-empty),
    |(with .else {
          when SAST::Empty   { Empty }
          when SAST::If    { "\n{$*pad}",|self.node($_,:else) }
          when SAST::Stmts { "\n{$*pad}else\n",|self.node($_,:indent,:no-empty) }
      } elsif .type ~~ tBool {
         # if false; then false; fi; actually exits 0 (?!)
         # So we have to make sure it exits 1 if the cond is false
         "\n{$*pad}else\n{$*pad}  false"
     }),
    ( "\n{$*pad}fi" unless $else );
}

# turns stuff like:
# if test "$(cat $file)"; do ...
# into:
# if _1="$(cat $file)"; if test "$_1"; do ...
method compile-topic($topic-var, @associated-sast) {
    if not $topic-var.defined {
       Empty
    }
    elsif $topic-var.references > 1 {
        |self.node($topic-var),'; '
    }
    elsif $topic-var.references == 1 {
        search-and-replace(
            $topic-var.references[0],
            $topic-var.assign,
            @associated-sast,
        )
        ?? Empty
        !! SX::Bug.new(desc => "Unable to find reference to topic variable in if statement").throw
    }
    else {
        Empty;
    }
}
sub search-and-replace($target, $replacement, @places-to-look) {
    for @places-to-look <-> $thing {
        $thing.descend({ $_ === $target and $_ = $replacement }) and return True;
    }
    return False;
}

multi method arg(SAST::If:D $_) {
    nextsame if .type ~~ tBool;
    if not .else
       and (my $stmt = .then.one-stmt)
       and not (.topic-var andthen .depended) {
        # in some limited circumstances we can simplify
        # if cond { action } to cond && action
        my $neg = .cond ~~ SAST::Neg;
        my $cond = $neg ?? .cond[0] !! .cond;

        if $cond ~~ SAST::Var && (my $var = $cond)
           or
           $cond ~~ SAST::Cmd && $cond.nodes == 2
           && $cond[0].compile-time ~~ 'test'
           && $cond[1] ~~ SAST::Var
           && ($var = $cond[1])
        {
            dq '${',self.gen-name($var), ($neg ?? ':-' !! ':+'),
                    |self.arg($stmt).itemize($stmt.itemize),'}';
        } else {
            cs |self.cond($cond),
               ($neg ?? ' || ' !! ' && '),
               |self.node(.then, :one-line);
        }
    } else {
        callsame;
    }
}

multi method cap-stdout(SAST::If:D $_) {
    nextsame if .type ~~ tBool;
    self.node($_);
}

#!Loop
multi method node(SAST::Loop:D $_) {
    |(.init andthen |self.node($_),'; '),
    'while ', |self.cond(.cond),"; do\n",
    |self.node(.block, :indent, :no-empty),
    |(.incr andthen "\n", |self.compile-nodes([$_], :indent)),
    "\n{$*pad}done";
}
multi method cap-stdout(SAST::Loop:D $_) { self.node($_) }

#!While
multi method node(SAST::While:D $_) {
    .until ?? 'until' !! 'while',' ',
    |self.compile-topic(.topic-var, (.cond, .block)),
    |self.cond(.cond),"; do\n",
    |self.node(.block,:indent,:no-empty),
    "\n{$*pad}done";
}
multi method cap-stdout(SAST::While:D $_) { self.node($_) }
#!Given
multi method node(SAST::Given:D $_) {
    |self.compile-topic(.topic-var, (.block,)),
    |self.node(.block,:curlies)
}

multi method cond(SAST::Given:D $_) { self.node($_) }

multi method arg(SAST::Given:D $_) { cs self.node($_) }
#!For
multi method node(SAST::For:D $_) {
    'for ', self.gen-name(.iter-var), ' in ', |self.arglist(.list.children)
    ,"; do\n",
    |self.node(.block,:indent,:no-empty),
    "\n{$*pad}done"
}
multi method cap-stdout(SAST::For:D $_) { self.node($_) }
