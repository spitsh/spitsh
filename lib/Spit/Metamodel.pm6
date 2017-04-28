need Spit::Exceptions;
need Spit::Constants;
need DispatchMap;

# Role for parameterized types like List[Str]
role Spit::Parameterized[*@params] {
    method params { @params }
}

class Spit::Metamodel::EnumClass {...}

role Spit::Type {
    # Make Spit::Types true so we can use them in if statements
    method Bool { self === Spit::Type ?? False !! True }
    method name { self.^name }
    method primitive { self.^primitive }
    method is-primitive { self === self.primitive }
    method parameterized { so self ~~ Spit::Parameterized && self.params }
    method enum-type {  so self.HOW ~~ Spit::Metamodel::EnumClass }
    method WHICH { self.^name ~ '|' ~ self.^spit-type-id }
}

BEGIN my $id-counter = 0;

class Spit::Metamodel::Type is Metamodel::ClassHOW {
    has Mu $!primitive;
    has $!dispatcher = DispatchMap.new;
    has $!num-params = 0;
    has @!placeholder-params;
    has $!declaration;
    has %!param-type-cache;
    has $!spit-type-id = $id-counter++;

    method new_type(|) {
        my \type = callsame;
        type.^add_role(Spit::Type);
        type;
    }

    method dispatcher(Mu $) { $!dispatcher }

    method add-spit-method(Mu $type,$sast-routine) {
        $!dispatcher.override(|($sast-routine.name => $sast-routine.os-candidates));
        $!dispatcher.ns-meta($sast-routine.name) = $sast-routine;
        $sast-routine;
    }

    method find-spit-method(Mu $type,Str:D $name,:$match) {
        $!dispatcher.ns-meta($name) || ($match && SX::MethodNotFound.new(:$name,:$type,:$match).throw);
    }

    method find-spit-method-on-os(Mu $type,Str:D $name,$os) {
        $!dispatcher.get($name,$os);
    }

    method spit-methods(Mu $) {
        $!dispatcher.namespaces.map({$!dispatcher.ns-meta($_)}).list;
    }

    method parameterize(Mu \type, *@params) {
        if @params {
                                              # .&WHAT is just here to decont
            my $cached := %!param-type-cache{\(|@params.map(*.&WHAT)).WHICH} and return $cached;
            my $name := "{type.^name}[{@params.map(*.name).join(", ")}]";
            my $what;
            my $role := Spit::Parameterized[|@params];

            my @permutations = [X] @params.map: *.^parents(:local).grep(Spit::Type);

            if @permutations {
                $what := Spit::Metamodel::Type.new_type(:$name);
                $what.^add_role($role);
                for @permutations -> \parent-params is raw {
                    $what.^add_parent(type.^parameterize(|parent-params));
                }
                $what.^set-primitive($what) if @params.grep(*.is-primitive);
                $what.^compose;
            } else {
                $what := type.^mixin($role);
                $what.^set_name($name);
                $what.^set-primitive: $what;
                $what.^compose;
            }
            $cached = $what;
        } else {
            type;
        }
    }

    method primitive(Mu $type) { $!primitive  }
    method set-primitive(Mu $,Mu $primitive) { $!primitive = $primitive }
    method declaration(Mu $) { $!declaration }
    method set-declaration(Mu $,Mu $declaration) { $!declaration = $declaration }
    method placeholder-params(Mu $) { @!placeholder-params }

    method add_parent(Mu $type,Mu $parent) {
        $!dispatcher.add-parent($parent.^dispatcher) if $parent.HOW ~~ Spit::Metamodel::Type;
        if $parent ~~ Spit::Type and $parent.primitive {
            if $!primitive {
                if $!primitive === $parent.primitive or $!primitive ~~ $parent.primitive {
                    $!primitive = $parent.primitive;
                } else {
                    die "Incompatible primitive types in inheritence";
                }
            } else {
                $!primitive = $parent.primitive;
            }
        }
        callsame;
    }

    method compose(Mu $type){
        $!dispatcher.compose;
        die "Primitive not set on {$type.^name} at composition time" if $!primitive.WHAT =:= Mu;
        callsame;
    }

    method spit-type-id(Mu $) { $!spit-type-id }

}

# metaclass for placeholder types like
# class List[PlaceHolderType] {
#     method foo(-->PlaceHolderType) {...}
# }
class Spit::Metamodel::Placeholder is Spit::Metamodel::Type {
    has $!param-pos;
    has Spit::Type $!param-of;
    method set-param-of(Mu $,Mu $!param-of,Int:D $!param-pos) { }
    method param-pos(Mu $) { $!param-pos }
    method reify(Mu $,Spit::Type $class) {
        $class.params[$!param-pos]
    }
}

class Spit::Metamodel::EnumClass is Spit::Metamodel::Type {
    has @!children;

    method add_parent(Mu $type,Mu $parent) {
        callsame;
        if $parent.HOW ~~ Spit::Metamodel::EnumClass {
            $parent.^add_child($type);
        }
    }

    method add_child(Mu $,Mu $child) {
        @!children.push($child);
        Nil;
    }

    method types-in-enum(Mu $type) { $type, |@!children.map(*.^types-in-enum).flat }

    method prmitive(Mu $type) { $type }

    method lookup-by-str(Mu $type,Str $str) {
        $type.^types-in-enum.first: { .^name.lc ~~ $str.lc };
    }

    method children(Mu $) { @!children.list }
}
