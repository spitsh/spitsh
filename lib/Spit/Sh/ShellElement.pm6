use MONKEY-TYPING;

# using constant here goofs for some reason
my $metachar-re = BEGIN rx/\s|<[}<?'"\\$;&()|>*#`]>/;
my $case-meta = BEGIN rx/<[[*?|]>/;

role ShellElement {

    method in-case-pattern {
        S:g!$case-meta | \\ <?before $case-meta>!\\$/! given self.in-DQ.join;
    }
}

# Make Str a shell element that is just pasted raw into the shell
BEGIN augment class Str does ShellElement {
    method as-item { self }
    method as-flat { self }
    method in-DQ   { self }
    method in-ctx  { self }
    method itemize($)  { self }
    method faltten  { self }
    method in-param-expansion { self }
};

# Role for anything that has to have its itemization or
# quoting context considered before putting it into the shell.
role DynamicShellElement does ShellElement {
    has Bool:D $.itemized = True;
    method Slip { self.in-ctx.Slip }
    method Str { self.in-ctx.join }
    method in-ctx { $!itemized ?? self.as-item !! self.as-flat }
    method itemize($!itemized) { self }
    method match(|c)    { self.Str.match(|c)  }
    method in-param-expansion { self.in-DQ }
}

# A literal string - it should be escaped for whatever quotes it appears in
class Escaped does DynamicShellElement {
    has $.str is required;

    method backslashes {
        S:g!$metachar-re!\\$/! given $!str;
    }

    method in-SQ {
        $!str.subst("'","'\\''",:g);
    }

    method in-DQ(:$next) {
        S:g!
            |<[$"`]>
            |\\ [ <?[\\$"`]> || $ <?{$next andthen .match(/^<?[\\$"`]>/)}> ]
        !\\$/! given $!str;
    }

    method as-item {
        return "''" if not $!str;
                                # can't \ to quote vertical whitespace in shell
        if $!str.chars == 1 and $!str !~~ /\v/ {
            self.backslashes;
        } elsif $!str.contains("'") {
            '"',self.in-DQ,'"';
        } elsif  $!str ~~ $metachar-re {
            "'$!str'"
        } else {
            $!str
        }
    }

    # Parameter expansion: ${foo:+bar}
    # like double quotes but need to escape } too.
    method in-param-expansion(:$next) {
        S:g!
           |<[$"`}]>
           |\\ [ <?[\\$"`}]> || $ <?{$next andthen .match(/^<?[\\$"`}]>/)}> ]
           !\\$/! given $!str;
    }


    method as-flat { self.as-item }
}

class Concat does DynamicShellElement {
    has @.elements;

    method in-DQ {
        my @in-DQ;

        for @!elements.reverse.kv -> $i,$_ {
            @in-DQ.prepend(.in-DQ(next => @in-DQ.head));
        }

        @in-DQ;
    }

    method in-param-expansion {
        my @in-DQ;

        for @!elements.reverse.kv -> $i,$_ {
            @in-DQ.prepend(.in-param-expansion(next => @in-DQ.head));
        }

        @in-DQ
    }

    method as-item { '"',|self.in-DQ, '"'}
    method as-flat { self.as-item }
}

# something that has different meaning if it's inside double quotes
class DoubleQuote does DynamicShellElement {
    has @.bits;
    method in-DQ { @!bits }
    method as-item { '"',|@!bits,'"' }
    method as-flat { @!bits }
    method in-param-expansion { @!bits }
}

# a vanilla variable.
class DoubleQuote::Var does DynamicShellElement {
    has $.name;
    has Bool $.is-int;
    method in-DQ(:$next) { ($next andthen m/^\w/) ?? ('${',$!name,'}') !! ('$',$!name) }
    method as-item { ('"' unless $!is-int),'$',$!name,('"' unless $!is-int) }
    method as-flat { '$',$!name }
    method in-case-pattern(|c) { self.in-DQ(|c) }
}

# an element that will has the same meaning inside and outside ""
# e.g. arithmetic expansion $((1+1))
class NoNeedQuote does DynamicShellElement {
    has @.bits;
    method in-DQ { @!bits }
    method as-item { @!bits }
    method as-flat { @!bits }
    method in-case-pattern { @!bits }
}

# $@ or $* depending on context
class DollarAT does DynamicShellElement {
    method in-DQ   { '$*'   }
    method as-item { '"$*"' }
    method as-flat { '"$@"' }
}


sub nnq    is export { NoNeedQuote.new: bits => @_ }
sub dq     is export { DoubleQuote.new: bits => @_ }
sub escape is export { Escaped.new: str => @_.join  }
sub cs     is export { DoubleQuote.new: bits => ('$(',|@_,')')}
sub var    is export { DoubleQuote::Var.new: name => $^a, :$:is-int }
sub concat is export { Concat.new: elements => @_ }
