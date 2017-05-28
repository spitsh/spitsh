# A Dumping ground for subs used in Spit/SAST.pm6
unit module Spit::Stage2-Util;
need Spit::Exceptions;
need Spit::Constants;
use Spit::Metamodel;

# Validates and puts arguments through stage2.
# It was too huge to put in SAST::Call so it's here
sub do-stage2-call ($call, $declaration) is export {
    my @pos := $call.pos;
    my %named := $call.named;
    my $signature := $call.signature;
    my (@pos-params,%named-params) := ($signature.pos,$signature.named);
    my $slurpy = @pos-params ?? @pos-params[*-1].slurpy !! False;
    my $pos-args := @pos.iterator;
    my $last-valid;

    for @pos-params.kv -> $i,$param {
        if $param.slurpy {
            until (my $arg := $pos-args.pull-one) =:= IterationEnd {
                $arg .= do-stage2(
                    # Str *$foo: puts arguments in Str context
                    # Str *@foo: puts arguments in List[Str] context
                    ($param.sigil eq '$' ?? $param.type.^params[0] !! $param.type),
                    :desc("argument slurped by {$param.spit-gist} " ~
                          "in {$declaration.spit-gist} doesn't match its type")
                );
            }
        } else {
            if (my $arg := $pos-args.pull-one) !=:= IterationEnd {
                $arg .= do-stage2(
                    $param.type,
                    :desc("argument {$i + 1} to {$declaration.spit-gist} doesn't match its type")
                );
                $last-valid := $arg;
            }
            else {
                next if $param.optional;

                my @non-slurpy = @pos-params.grep(!*.slurpy);
                SX::BadCall::WrongNumber.new(
                    :$declaration,
                    expected => +@non-slurpy,
                    got => +@pos,
                    match => ($last-valid andthen .match or $call.match),
                    at-least => ?$signature.slurpy-param,
                    arg-hints => @non-slurpy[+@pos..*]».spit-gist,
                ).throw;
            }
        }
    }

    if (my $extra-arg := $pos-args.pull-one) !=:= IterationEnd {
        SX::BadCall::WrongNumber.new(
            :$declaration,
            expected => +@pos-params,
            got => +@pos,
            match => $extra-arg.match,
        ).throw;
    }

    for %named.kv -> $name, $arg is rw {
        if %named-params{$name} -> $param {
            $arg .= do-stage2(
                $param.type,
                :desc("named argument {$param.spit-gist} to $name doesn't match its type")
            );
        } else {
            SX::BadCall.new(
                :$declaration,
                reason => "Unexpected named argument '$name'.",
                match => $arg.match,
            ).throw;
        }
    }
}

sub class-by-name($name) is export {
    with $*SETTING.lookup(CLASS,$name) {
        .class
    } else {
        die "internal error: class $name used before it's declared";
    }
}

# A pair where the value has container we can mess with
sub cont-pair($a,$b is copy) is export {
    $a => $b
}

sub tListp(Spit::Type \elem-type) is export {
    elem-type ~~ tList ?? elem-type !! tList.^parameterize(elem-type);
}
sub tPairp(Spit::Type \key, \value) is export {
    tPair.^parameterize(key,value);
}

# The type of the thing if it were flattened out
sub flattened-type(Spit::Type $_) is export {
    when tList {
        if .^parent-derived-from(tList) -> $parameterized {
            $parameterized.^params[0];
        } else {
            tStr;
        }
    }
    default { $_ }
}


sub derive-common-parent(*@types) is export {
    my $cmp-to = @types.shift;
    for @types {
        $cmp-to = .^mro.first: { $cmp-to ~~ $_ }
    }
    return $cmp-to;
}

sub type-from-sigil(Str:D $sigil --> Spit::Type) is export {
    do given $sigil {
        when '$' { tStr }
        when '@' { tList }
        default { die "got bogus sigil '$sigil'" }
    };
}

sub symbol-type-from-sigil(Str:D $_ --> SymbolType) is export {
    when '$' { SCALAR }
    when '@' { ARRAY  }
    default { die "got boigus sigil '$_'" }
}

sub itemize-from-sigil(Str:D $_ --> Bool:D) is export {
    when '@' { False }
    default { True }
}

sub figure-out-var-type($sigil, $type is rw, \decl-type, :$assign is raw, :$desc) is export {
    my $sigil-type := type-from-sigil($sigil);
    if decl-type {
        $type = do if $sigil-type === tList {
            tListp(decl-type);
        } else {
            decl-type;
        };

        $assign .= do-stage2($type,:$desc) if $assign;
    } else {
        $type = do if $assign {
            $assign .= do-stage2($sigil-type, :$desc);
            $assign.type;
        } else {
            if $sigil-type === tList {
                tListp(tStr);
            } else {
                $sigil-type;
            }
        }
    }
}
