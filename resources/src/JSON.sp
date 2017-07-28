#| The JSON class represents any valid JSON;
augment JSON { # is Str is primitive
    method pretty-->JSON { $self.${$:jq} }

    # These are all dealt with in the composer. Chained method calls
    # are all rolled into a single call to at-path or set-path
    method at-key($key)^               is native {}
    method at-pos(Int $pos)^           is native {}
    method at-list-pos(Int @pos)^      is native {}
    method set-key($key, $value) is rw is native {}
    method set-pos($pos, $value) is rw is native {}
    method keys@                       is native {}
    method values@                     is native {}
    method List                        is native {}
    method merge(JSON $object)^        is native {}
    method ACCEPTS(JSON $b)?           is native {}

    method at-path(*@args)* {
        $self.${ $:jq -cr @args }
    }
    method set-path(*@args)* is rw {
        $self.${ $:jq -c @args }
    }
    method bool-path(*@args)? {
        $self.${ $:jq -e @args *>X}
    }

    method defined? { $self.${$:jq -e '.' *>X} }
    method Bool?    { $self.defined && $self.${$:jq '.'}-->Str.Bool }
    static method null^ { 'null'-->JSON }
}

sub j-array(JSON *@json)-->JSON {
    ('[' ~ @json.join(',') ~ ']')-->JSON
}

sub j-object(JSON *$json)-->JSON {
    (
        '{' ~
        (loop (my $j = 0; $j < $json; $j += 2) {
            $json[$j] ~ ':' ~ $json[$j+1]
        }).join(',') ~
        '}'
    )-->JSON;
}

augment List[JSON] {
    method sort($key)^ {
        $self.${$:jq -rcs "sort_by(.$key)|.[]"}
    }
}
