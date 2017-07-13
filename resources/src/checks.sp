##| Returns the text as green.
#sub green($txt)~ { ${printf '\\33[0;' ~ 32 ~ 'm%s\\33[0m', $txt} }
##| Returns the text as red.
# sub red($txt)~   { ${printf '\\33[0;' ~ 31 ~ 'm%s\\33[0m', $txt}  }

constant $:check-log-success-symbol = "\c[WHITE HEAVY CHECK MARK]";
constant $:check-log-failure-symbol = "\c[CROSS MARK]";
#| If the condition true, ok prints the message with a friendly
#| '✔'. Otherwise, dies with an angry '✘'.
#|{
   ok True,"";
}
sub ok (#|[The success condition] Bool $cond,
        #|[The associated message] $msg?) {
    $cond
        ??  ($:log ?? $msg.log(2, $:check-log-success-symbol)
                   !! say "✔ - $msg")
        !!  ($:log ?? $msg.log($:log-fatal-level, $:check-log-failure-symbol)
                   !! die "✘ - $msg")
}

#|If the two strings are equal, prints the message with a friendly
#| '✔'. Otherwise, displays the two strings and dies with an angry '✘'.
#|{
    is File</etc/meaning-of-life.cfg>.slurp,'42',"configured with correct MOL";
}
sub is (#|[The string to check] $got,
        #|[The expected string] $expected,
        #|[The associated message] $msg?) {

    $got eq $expected
        ?? pass "$msg"
        !! flunk “{$msg && "$msg - "}Expected '$expected' but got '$got'”;
}

#| The negated form of `ok`. Succeeds when the $cond is false.
sub nok(Bool $cond,$msg?)  { ok !$cond,$msg }
#| Prints a message with a friendly ✔.
sub pass ($msg?) { ok True, $msg }
#| Prints a message and dies angrily ✘.
sub flunk ($msg?) { ok False,$msg }
