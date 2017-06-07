need Spit::SAST;
need Spit::Exceptions;
need Spit::Constants;

unit role Name-Generator;

has Hash @.names;

method !avoid-name-collision($decl,$name is copy,:$fallback) {
    $name ~~ s:g/\W/_/;
    my $st = $decl.symbol-type;
    $st = SCALAR if $st == ARRAY;
    my $existing := @!names[$st]{$name};
    my $res = do given $existing {
        when :!defined { $name }
        when $fallback.defined { return self!avoid-name-collision($decl,$fallback) }
        when /'_'(\d+)$/ { $name ~ ('_' unless $name eq '_') ~ $/[0] + 1; }
        default { $name ~ ('_' unless $name eq '_') ~ '1' }
    }
    $existing = $res;
}


multi method gen-name(SAST::Declarable:D $decl,:$name is copy = $decl.bare-name,:$fallback)  {
    self.check-stage3($decl);
    $name = do given $name {
        when '/' { 'M' }
        when '~' { 'B' }
        default { $_ }
    };

    do with $decl.ann<shell_name> {
        $_;
    } else {
        # haven't given this varible its shellname yet
        $_ = self!avoid-name-collision($decl,$name,:$fallback);
    }
}

multi method gen-name(SAST::PosParam:D $_) {
    if .slurpy {
        self.scaf('?IFS');
        '*'
    }
    elsif .signature.slurpy-param {
        callsame;
    }
    else {
        .shell-position.Str;
    }
}

multi method gen-name(SAST::Invocant:D $_) {
    .piped and
      SX::Bug.new(desc => "Tried to compile a piped invocant ({.WHICH}, votes: {.pipe-vote})", match => .match).throw;
    if .signature.slurpy-param {
        callsame;
    } else {
        '1';
    }
}

multi method gen-name(SAST::Var:D $_ where { $_ !~~ SAST::VarDecl }) {
    self.gen-name(.declaration);
}

multi method gen-name(SAST::EnvDecl:D $_) {
    my $name = callsame;
    if $name ne .bare-name {
        .make-new(SX,message => "Unable to reserve ‘{.bare-name}’ for enironment variable.").throw;
    }
    $name;
}

multi method gen-name(SAST::MethodDeclare:D $method) {
    callwith($method,fallback => $method.class-type.name.substr(0,1) ~  $method.name);
}

multi method gen-name(SAST:D $node) {
    SX::BugTrace.new(
        desc => "Tried to generate a name for a {$node.^name}",
        bt => Backtrace.new,
        match => $node.match
    ).throw;
}
