sub ef($test, $str)~ is native  { }
sub et($test, $str)~  is native { }

#| Joins arguments on a `\n` creating a `List`.
sub list(*$list)@ is no-inline {
    $list ?? ${printf '%s\n' $list} !! ();
}

# Internal helper for echoing values
sub e($str)~     ${printf '%s' $str}
#| Prints its argument to `$:OUT` with a newline
sub say($str)?   ${printf '%s\\n' $str > $:OUT}
#| Prints its argument to `$:ERR` with a newline.
sub note($str)?  ${printf '%s\\n' $str >! }
#| Prints its argument to `$:OUT` with no newline.
sub print($str)? ${printf '%s' $str > $:OUT }

constant $:log-die-path = "\c[SKULL]";
#| Prints the message to stdout and then exits
sub die($str)*  {
    $:log ?? ("$str".log($:log-fatal-level, $:log-die-path); ())
          !! (note($str) && $?PID.kill; ())
}

#| Suspends execution for an interval of time measured in seconds.
#| **note** `sleep(1)` can usually take floating point numbers but
#| they are NYI in spit.
sub sleep(Int $seconds) { ${sleep $seconds} }

#| Prompts the user with a yes/no question and returns a Bool with the
#| answer. If `$:interactive` is false then it will just return the default.
#|{
    if prompt("Did the chicken come before the egg?", :default(True)) {
        say "wrong, the egg came before the chicken.";
    } else {
        say "wrong, the chicken DID come before the egg.";
    }
}
sub prompt(
    #|[The question to pose to the user]Str $question,
    #|[The default answer] Bool :$default)? {
    if $:interactive {
        my $yn = $default ?? '[Y/n]' !! '[y/N]';
        say "👻 $question $yn";
        $?IN.get;
        given $~ {
            when ''       { $default  }
            when /^[yY]$/ { True      }
            when /^[nN]$/ { False     }
            default { prompt($question, :$default) }
        }
    } else {
        $default;
    }
}

sub not(Bool $thing)? { !$thing }
