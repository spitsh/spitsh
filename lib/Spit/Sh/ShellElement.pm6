use MONKEY-TYPING;

# using constant here goofs for some reason
my $metachar-re = BEGIN rx/\s|<[}<?'"\\$;&()|>*#]>/;

role ShellElement {
    method in-or-equals {
        S:g!'}' | \\<?before '}'>!\\$/! given self.in-DQ.join;
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
            |'"'
            |\\ [ <?[\\$"]> || $ <?{$next andthen .match(/^<?[\\$"]>/)}> ]
            |'$'
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

    method as-flat { self.as-item }
}

# something that has different meaning if it's inside double quotes
class DoubleQuote does DynamicShellElement {
    has @.bits;
    method in-DQ { @!bits }
    method as-item { '"',|@!bits,'"' }
    method as-flat { @!bits }
}

# a vanilla variable.
class DoubleQuote::Var does DynamicShellElement {
    has $.name;
    has Bool $.is-int;
    method in-DQ(:$next) { ($next andthen m/^\w/) ?? ('${',$!name,'}') !! ('$',$!name) }
    method as-item { ('"' unless $!is-int),'$',$!name,('"' unless $!is-int) }
    method as-flat { '$',$!name }
}

# an element that will has the same meaning inside and outside ""
# e.g. arithmetic expansion $((1+1))
class NoNeedQuote does DynamicShellElement {
    has @.bits;
    method in-DQ { @!bits }
    method as-item { @!bits }
    method as-flat { @!bits }
}
