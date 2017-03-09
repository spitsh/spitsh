use nqp;
use NQPHLL:from<NQP>;
use Spit::Constants;
constant $error-lines = 4;
class SX is Exception is rw {

    has $.pre is required;
    has $.post is required;
    has $.marked;
    has $.line is required;
    has $.message;
    has $.cu-name is required;

    multi method new(:$node!,|a) {
        callwith(match => $node.match,:$node,|a);
    }

    multi method new(:$match!,:$after,|a) {
        my $orig := $match.orig;
        my $pre = $orig.substr(0,$match.from);
        my $post = $orig.substr($match.to);
        if $pre.lines > $error-lines {
            my @pre = $pre.lines[(* - $error-lines)..*];
            @pre.shift while @pre[0] ~~ /^\s*$/;
            $pre = "......\n" ~ @pre.join("\n") ~ ("\n" if $pre.ends-with("\n"));
        }
        if $post.lines > $error-lines {
            my @post = $post.lines[0..($error-lines -1)];
            @post.pop while @post[*-1] ~~ /^\s*$/;
            $post = @post.join("\n") ~ "\n......";
        }
        my $marked = do if $after {
            $pre ~= $match.Str;
            if $pre ~~ s/(\s+)$// {
                $post = $/[0].Str ~ $post;
            }
            '⏏'
        } else {
            '⏏' ~ $match.Str;
        }
        my $line = HLL::Compiler.lineof($orig,$match.from);
        self.bless(:$pre,:$post,:$marked,:$line,cu-name => $*CU-name,|a);
    }

    multi method new(|a) {
        my $match = CALLER::LEXICAL::<$/>;
        self.new(:$match,|a);
    }

    method gist {
        my ($red,$clear,$green,$yellow,$eject) = Rakudo::Internals.error-rcgye;
        "ERROR while compiling $!cu-name: " ~
        "$.message\n$!cu-name:$!line\n$green$.pre$yellow$.marked$red$.post$clear" ;
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

class SX::Syntax is SX {
    has $.problem;
    method message { "Invalid $!problem." }
}

class SX::Expected is SX {
    has Str:D $.expected is required;

    method message { "Expected $!expected." }
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

class SX::Redeclaration is SX {
    has $.name is required;
    has $.type is required;
    has Match:D $.orig-match is required;

    method message {
        my $line = HLL::Compiler.lineof($!orig-match.orig,$!orig-match.from);
        "$!type $!name already declared on line $line.";
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
}

class SX::UndeclaredSpecial is SX {
    has Str:D $.name is required;
    has $.class is required;

    method message {
        "no special found with name '$!name' for class '{$!class.^name}'";
    }
}

class SX::UndeclaredSpecialOnOS is SX::UndeclaredSpecial {
    has $.os is required;
    has @.candidates;

    method message {
        "unable to find a definition for special {$.class.^name}<*$.name> on {$!os.gist}\n" ~
        "It has definitions on the following operating systems:\n" ~
        "   " ~ @!candidates.map(*.gist).join("   \n");

    }
}

class SX::BadCall is SX {
    has $.declaration is required;
    has $.reason is required;
    method message { "Invalid call to {$.declaration.spit-gist}.\n$!reason" }
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
    has $.desc is required;
    method message {
        "$!desc - This is a bug";
    }
}

class SX::CompStageNotCompleted is SX {
    has $.stage is required;
    has $.node is required;

    method message {
        "Compilation stage $!stage for {$.node.WHICH}({$.node.gist}) hasn't been completed. This is a bug."
    }

}

class SX::NoSelf is SX {

    method message {
        "'self' used outside of a class definition.";
    }
}
