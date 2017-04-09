use MONKEY-TYPING;
constant @metachars = Qw[ } < ? ' " \ $ ; & ( ) | > * # ]; #>'

role ShellElement {
    method in-or-equals {
        S:g!('}' | \\<?before '}'>)!\\$0! given self.in-DQ.join;
    }
    method contains-metachar(*@metachars) { ?self.match(/@metachars/) }
    method starts-with-ident { ?self.match(/^\w/) }
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
    has @.bits;

    method backslashes {
        S:g/(@metachars|\h)/\\$0/ given @!bits.join #"
    }

    method in-SQ {
        @!bits.join.subst("'","'\\''",:g);
    }

    method in-DQ(:$next) {
            S:g!(
                |'"'
                |\\ [ <?[\\$"]> || $ <?{$next andthen .match(/^<?[\\$"]>/)}> ]
                |'$'
            ) !\\$0! given @!bits.join;
    }

    method as-item {
        return "''" if not @!bits or @!bits.all eq '';
        if @!bits.first({.contains-metachar("'")}) {
            '"',self.in-DQ,'"';
        } elsif @!bits.first(*.contains-metachar(@metachars)|/\s/) {
            "'",|@!bits,"'"
        } else {
            self.backslashes;
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
    method in-DQ(:$next) { ($next andthen .starts-with-ident) ?? ('${',$!name,'}') !! ('$',$!name) }
    method as-item { ('"' unless $!is-int),'$',$!name,('"' unless $!is-int) }
    method as-flat { '$',$!name }
    method contains-metachar(|) { False }
    method starts-with-ident { False }
}

# an element that will has the same meaning inside and outside ""
# e.g. arithmetic expansion $((1+1))
class NoNeedQuote does DynamicShellElement {
    has @.bits;
    method in-DQ { @!bits }
    method as-item { @!bits }
    method as-flat { @!bits }
    method contains-metachar(|) { False }
}
