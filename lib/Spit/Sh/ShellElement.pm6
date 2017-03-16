use MONKEY-TYPING;
constant @metachars = Qw{ < ? ' " \ $ ; & ( ) | > *}; #>'

role ShellElement { }

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
    method contains(|c) { ?@.bits».contains(|c).any }
    method match(|c) { ?@.bits».match(|c).any }
}

# A literal string - it should be escaped for whatever quotes it appears in
class Escaped does DynamicShellElement {
    has @.bits;

    method backslashes {
        S:g/@metachars|\h/\\$// given @!bits.join #"
    }

    method in-SQ {
        @!bits.join.subst("'","'\\''",:g);
    }

    method in-DQ {
        S:g/\"|\\<?before \"|\$>|\$/\\$// given @!bits.join; #"
    }

    method as-item {
        return "''" if not @!bits or @!bits.all eq '';
        if @!bits.first({.contains("'")}) {
            '"',self.in-DQ,'"';
        } elsif @!bits.first({.contains(@metachars.any) || ?/\s/}) {
            "'",@!bits.join,"'"
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
    method in-DQ { '${',$!name,'}' }
    method as-item { '"$',$!name,'"' }
    method as-flat { '$',$!name }
    method contains(|) { False }
    method match(|) { False }
}

# an element that will has the same meaning inside and outside ""
class NoNeedQuote does DynamicShellElement {
    has @.bits;
    method in-DQ { @!bits }
    method as-item { @!bits }
    method as-flat { @!bits }
}
