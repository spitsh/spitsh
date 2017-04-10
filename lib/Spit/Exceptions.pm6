use Spit::Constants;
use Terminal::ANSIColor;

multi line-start(Match:D $match,Str:D $orig = $match.orig) {
    $orig.substr(0,$match.from).lines.elems;
}
multi line-start(Int:D $from,Str:D $orig) {
    $orig.substr(0,$from).lines.elems;
}

sub gen-ctx(+@marks,
            :$orig is copy,
            Int :$middle-line is copy,
            :$lines = 6,
            :$before is copy = '',
            :$after = '',
            :$yada,
           ) {

    $orig //= @marks[0]<match>.orig;
    my @orig = $orig.comb;

                    # find the average
    $middle-line //= (@marks.map({ line-start( .<from match>.first(*.defined), $orig) }).sum/@marks).Int;

    my $offset = 0;

    @marks .= sort({ .<to> || .<match>.to });

    for @marks -> (:$before,:$after,:$match,:$from is copy, :$to is copy) {
        $from //= $match.from; $to //= $match.to; # BUG in rakudo can't do it in signature

        if $before {
            @orig[$from] = $before ~ @orig[$from];
        }

        if $after {
            my $insert = $to - 1;
            $insert = 0 if $insert < 0;
            $insert-- while $insert > 0 and @orig[$insert] ~~ /^\s*$/;
            @orig[$insert] ~= $after;
        }
    }

    $orig = @orig.join;

    my $start-line = $middle-line - ($lines/2).Int;

    if $start-line < 0 {
        $start-line = 0;
    } else {
        $before ~= "$yada\n" if $yada;
    }

    my @lines;

    for $orig.lines[$start-line..*] {
        if @lines or not /^\s*$/ {
            @lines.push($_);
        }

        last if @lines >= $lines;
    }

    @lines[0] = $before ~ @lines[0];
    @lines[*-1] ~= $after;
    return @lines.join("\n");
}

my constant \GRAY = color("242");
my constant \YELLOW = color("yellow");

class SX is Exception is rw {
    has $.message;
    has $.line is required;
    has $.match is required;
    has $.cu-name is required;

    multi method new(:$node!,|a) {
        callwith(match => $node.match,:$node,|a);
    }

    multi method new(:$match is copy,|c) is default {
        if not $match {
            my $tmp = OUTER::CALLER::LEXICAL::<$/>;
            $match = $tmp // Nil;
        }
        my $line = $match.&line-start;
        self.bless(:$line,cu-name => $*CU-name,:$match,|c);
    }

    method gist {
        my $snippet := gen-ctx :before(GRAY), :after(RESET),
        ${ :before(RESET() ~ $.mark-before), :after($.mark-after ~ RESET() ~ GRAY), :$.match },
        |self.extra-marks;

        self.ERROR ~ " $.message\n$!cu-name:$!line\n$snippet";
    }

    method mark-before { color("on_red") }
    method mark-after  { '' }
    method extra-marks { Empty }

    method ERROR { colored("ERROR","red") ~ " while compiling $!cu-name:"}
}

class SX::Unbalanced is SX {
    has Match:D $.opener is required;
    has $.closer is required;
    has $.desc;

    method gist {
        my $o-line = $.opener.&line-start;
        if $.line - $o-line < 8 {
            my $snippet := gen-ctx :lines(8), :before(GRAY), :after(RESET),
            ${ :before(YELLOW ~ BOLD()),
               :after(BOLD_OFF() ~ RESET), match => $!opener },
            ${ :after(colored(colored(" $!closer↩","green"),"bold") ~  GRAY), :$.match};
            self.ERROR ~ " $.message." ~
            "\n$.cu-name:$o-line\n$snippet";
        } else {
            my $o-snippet = gen-ctx :lines(4), :before(GRAY), :after(RESET),
            ${ :before(YELLOW ~ BOLD()),
               :after(BOLD_OFF() ~ RESET), match => $!opener };
            my $c-snippet = gen-ctx :after(RESET), :lines(4),
               :yada(GRAY ~  "====line:$.line===" ~ RESET),
            ${ :after(colored(colored(" $!closer↩","green"),"bold") ~ GRAY), :$.match };

            self.ERROR ~ " $.message\n" ~
            "$.cu-name:$o-line\n$o-snippet\n" ~
            "$c-snippet";
        }
    }

    method message {
        "Couldn't find closing ‘$.closer’{ $!desc andthen " to finish $_" }"
    }
}

class SX::TypeCheck is SX {
    has $.got is required;
    has $.expected is required;
    has $.desc;

    method message {
        "Type check failed{ $!desc andthen " for $_" }. Expected $!expected but got $!got.";
    }
}

class SX::Invalid is SX {
    has $.invalid;
    method mark-before { '' }
    method mark-after { colored('➧','red') }
    method message { "Invalid $!invalid." }
}

class SX::Expected is SX {
    has Str:D $.expected is required;
    has $.hint is required;

    method message { "Expected $!expected." }
    method mark-before { '' }
    method mark-after {
        if $!hint {
            colored("$!hint↩",'green');
        } else {
            colored('➧','red')
        }
    }
}

class SX::MethodNotFound is SX {
    has Str:D $.name is required;
    has $.type is required;

    method message { "Method '$!name' not found for invocant of class {$!type.^name}." }
}

class SX::RoutineNotDefOnOS is SX {
    has Str:D $.name is required;
    has $.os is required;
    has $.class;
    has @.candidates;

    method message {
        "{$!class ?? 'Method' !! 'Sub'}" ~
        " $!name { $!class andthen "on class {$!class.name} " }does't have a candidate that matches {$!os.name} OS." ~
        ("\nCandidates defined for: {@.candidates».name.join(', ')}." if @.candidates);
    }

}

class SX::OnBlockNotDefOnOS is SX {
    has @.candidates;
    has $.os is required;

    method message {
        “On block isn't defined on {$!os.name}.” ~
        ("\nCandidates defined for: {@.candidates».name.join(', ')}." if @.candidates);
    }
}

class SX::Redeclaration is SX {
    has $.name is required;
    has $.type is required;
    has Match:D $.orig-match is required;

    method message {
        "$!type $!name already declared on line {$!orig-match.&line-start}.";
    }
}

class SX::CallStubbed {
    has $.name is required;

    method message {
        "sub $!name was called but it is only a stub.";
    }
}

class SX::Undeclared is SX {
    has Str:D $.name is required;
    has $.type is required;

    method message {
        my $desc;
        my $name = $!name;
        if $!name.starts-with('*') {
            $name ~~ s/^'*'//;
            $desc = 'Option';
        } else {
            $desc = $.type.gist.wordcase;
            if $!type ~~ ARRAY|SCALAR {
                $desc ~=  ' variable';
            }
        }
        "$desc '$name' hasn't been declared.";
    }

    method mark-before { colored('➧','red') }
}

class SX::UndeclaredSpecial is SX {
    has Str:D $.name is required;
    has $.class is required;

    method message {
        "no special found with name '$!name' for class '{$!class.^name}'";
    }
}

class SX::BadCall is SX {
    has $.declaration is required;
    has $.reason;
    method message { "Invalid call to {$.declaration.spit-gist}.\n$.reason" }
}

class SX::BadCall::WrongNumber is SX::BadCall {
    has Int:D $.got is required;
    has Int:D $.expected is required;
    has @.arg-hints;
    method reason {
        ($!got > $!expected ?? "Too many" !! "Not enough") ~
        " positional arguments. Expected $!expected, got $!got.";
    }
    method mark-before {
        $!got > $!expected ?? callsame() !! ''
    }

    method mark-after {
        if $!got !== 0  and $!got < $!expected {
            colored(", $.hint↩",'green');
        }
    }

    method extra-marks {
        if $!got == 0 {
            my ($from,$hint);
            if $.match.orig.comb[$.match.to - 1] eq ')' {
                $from = $.match.to - 1;
                $hint = "$.hint↩";
            } else {
                $from = $.match.to;
                $hint = " $.hint↩";
            }

            (${ :after(colored($hint,'green')), :$from, :to($from) },)
        }
    }

    method hint { @.arg-hints.join(', ') }

}


class SX::Sh::ImpureCallAsArg is SX {
    has $.call-name is required;

    method message {
        "A call to an impure routine ($!call-name) cannot be used as an argument. " ~
        "Assign the result to a variable first and then pass the variable in its place.";
    }
}

class SX::Assignment-Readonly is SX {
    method message { "Can't assign to read-only value." }
}

class SX::RequiredOption is SX {
    has $.name is required;
    method message { "Option $!name used but no value provided for it and it doesn't have default." }
}

role SX::Module {
    has $.repo-type;
    has $.id;

    method module-gist { $.repo-type ?? $!repo-type ~ "<$!id>" !! $.id }
}

class SX::ModuleLoad does SX::Module is SX {
    has $.repo;
    has Exception:D $.exception is required;

    method message {
        "Loading $.module-gist from {$!repo.gist} failed. {$!exception.gist}";
    }

    method gist {
        do if $!exception ~~ SX {
            callsame() ~ "\n" ~
            $!exception.gist;
        } else {
            nextsame;
        }
    }
}

class SX::ModuleNotFound does SX::Module is SX {
    has @.repos;

    my $pad = "   ";
    method message {
        "Loading $.module-gist failed. Module not found in:\n$pad" ~
        @.repos».gist.join("\n$pad");
    }
}

class SX::NYI is SX {
    has $.feature is required;

    method message {
        "$.feature is not yet implemented!";
    }
}

class SX::Bug is SX {
    has $.desc;
    method message {
        "$.desc.\nThis is a bug. Please report it to: github.com/spitsh/spitsh/issues.";
    }
}

class SX::BugTrace is SX::Bug {
    has $.bt is required;
    method gist {
        callsame() ~ "\n----------\nPerl 6 Backtrace:\n" ~
        $.bt.Str;
    }
}

class SX::CompStageNotCompleted is SX::Bug {
    has $.stage is required;
    has $.node is required;

    method desc {
        "Compilation stage $!stage for {$.node.WHICH}({$.node.gist}) hasn't been completed"
    }

}

class SX::NoSelf is SX {

    method message {
        "'self' used outside of a class definition.";
    }
}
