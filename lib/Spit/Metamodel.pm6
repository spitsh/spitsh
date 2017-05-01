need Spit::Exceptions;
need Spit::Constants;
need DispatchMap;
use nqp;

# Spit uses Perl 6's Metamodel for doing type checking and method resolution.
# Method dispatching is handleded By DispatchMap.

# Spit::Metamodel::Type is the base metaobject type and is used for vanilla types
# eg class Foo { }
class Spit::Metamodel::Type {...}

# Parameterizable is the metaobject type for parameterizable types:
# eg class Foo[ParamType]
class Spit::Metamodel::Parameterizable {...}

# Parameterized is the specialized form of Parameterizable
# eg class Foo[ParamType] {...};
#    say Foo[Int] ⟵
class Spit::Metamodel::Parameterized {...}

# Parameter is the metaobject type for class parameters
# eg class Foo[ParamType ⟵] {...}
class Spit::Metamodel::Parameter {...}

# WhateverInvocant is the metaobject type for the Invocant of whatever
# class you're calling a method on. It's used by the * return type sigil.
class Spit::Metamodel::WhateverInvocant {...}

# EnumClass is the metaobject type for enum-class (used to declare
# operating systems). Keeps track of its children.
class Spit::Metamodel::EnumClass {...}

role Spit::Type {
    # Make Spit::Types true so we can use them in if statements
    method Bool { self === Spit::Type ?? False !! True }
    method name { self.^name }
    method primitive { self.^primitive }
    method is-primitive { self.^is-primitive }
    method enum-type {  so self.HOW ~~ Spit::Metamodel::EnumClass }
}

class Spit::Metamodel::Type is Metamodel::ClassHOW {
    has Mu $!primitive;
    has $!dispatcher = DispatchMap.new;
    has $!declaration;
    has Mu $!whatever-invocant;

    method new_type(|) {
        my \type = callsame;
        type.^add_role(Spit::Type);
        type;
    }

    method dispatcher(Mu $) { $!dispatcher }

    method add-spit-method(Mu $, $sast-routine) {
        $!dispatcher.override(|($sast-routine.name => $sast-routine.os-candidates));
        $!dispatcher.ns-meta($sast-routine.name) = $sast-routine;
        $sast-routine;
    }

    method find-spit-method(Mu $type, Str:D $name, :$match) {
        $!dispatcher.ns-meta($name) || $match && SX::MethodNotFound.new(
                                                 :$name,:$type,:$match).throw;
    }

    method find-spit-method-on-os(Mu $, Str:D $name, $os) {
        $!dispatcher.get($name,$os);
    }

    method spit-methods(Mu $) {
        $!dispatcher.namespaces.map({$!dispatcher.ns-meta($_)}).list;
    }

    method primitive(Mu $) { $!primitive  }
    method set-primitive(Mu $, Mu $primitive) { $!primitive = $primitive }
    method is-primitive(Mu \type) { type =:= nqp::decont($!primitive) }
    method declaration(Mu $) { $!declaration }
    method set-declaration(Mu $,Mu $declaration) { $!declaration = $declaration }

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

    method compose(Mu \type){
        $!dispatcher.compose;
        die "Primitive not set on {type.^name} at composition time" if $!primitive.WHAT =:= Mu;
        callsame;
        my \we-invocant = $!whatever-invocant;
        if we-invocant !=:= Mu and not we-invocant.^is_composed {
            we-invocant.^add_parent(type);
            we-invocant.^compose;
        }
        nqp::decont(type);
    }

    method reify(Mu $type, $with) { $type }

    method needs-reification(Mu $) { False }

    method whatever-invocant(Mu $type) {
        $!whatever-invocant ||=  Spit::Metamodel::WhateverInvocant.new_type();
    }

    method find-parameters-for(Mu \type,Mu \target) {
        my $parameterized := (type, |type.^parents).first({
            .HOW ~~ Spit::Metamodel::Parameterized
            && (.^derived-from === target)
        });
        $parameterized.^params if $parameterized;
    }

}

class Spit::Metamodel::Parameterizable is Spit::Metamodel::Type {
    has @!placeholder-params;

    method new_type(|) {
        my \type = callsame;
        nqp::setparameterizer(type, -> $, $params is raw {
            type.^produce-parameterization($params);
        });
        type;
    }

    method placeholder-params(Mu $) { @!placeholder-params }

    method parameterize(Mu \type, *@params) {
        my $params := nqp::list();
        for @params -> \param {
            nqp::push($params,nqp::decont(param));
        }
        nqp::parameterizetype(type, $params);
    }

    method produce-parameterization(Mu \type, @params) {
        my $name := "{type.^name}[{@params.map(*.^name).join(", ")}]";

        # Foo[Int,Bool] has to be a child of Foo[Int,Str],
        # Foo[Str,Int], Foo[Str,Str] etc. So we recursively find
        # and create the permuations and add them as parents.
        my @permutations = [X] @params.map: *.^parents(:local).grep(Spit::Type);
        my $what := Spit::Metamodel::Parameterized.new_type(:$name);
        $what.^set-params(@params);
        $what.^set-derived-from(type);

        if @permutations {
            for @permutations -> \parent-params is raw {
                $what.^add_parent(type.^parameterize(|parent-params));
            }
        } else {
            $what.^add_parent(type);
        }
        if type.^is-primitive and @params.first(*.^is-primitive) {
            $what.^set-primitive($what);
        }
        $what.^compose;
    }

    method reify-parameter(Mu $, Mu \param) {
        # Since this hasn't been parameterized yet, just return the
        # parameter's primitive (Str).
        param.^primitive;
    }
}

# metaclass for placeholder types like
# class List[PlaceHolderType] {
#     method foo(-->PlaceHolderType) {...}
# }
class Spit::Metamodel::Parameter is Spit::Metamodel::Type {
    has $!param-pos;
    has Spit::Type $!param-of;
    method set-param-of(Mu $,Mu $!param-of,Int:D $!param-pos) { }
    method param-pos(Mu $) { $!param-pos }

    method reify(Mu \param, Spit::Type \invocant-type) {
        invocant-type.^reify-parameter(param);
    }
    method needs-reification(Mu $) { True }
}

class Spit::Metamodel::Parameterized is Spit::Metamodel::Type {
    has @!params;
    has $!derived-from;

    method needs-reification(Mu $) {
        @!params.first(*.^needs-reification).so
    }
    method reify(Mu $, Mu \invocant-type) {
        my @reified-params = @!params.map(*.^reify(invocant-type));
        $!derived-from.^parameterize(@reified-params);
    }

    method parameterize(Mu $, @) {
        die "can't parameterize a Spit::Metamodel::Parameterized";
    }
    method derived-from(Mu $) { $!derived-from }
    method set-derived-from(Mu $, Mu \type) { $!derived-from = type };
    method params(Mu $) { @!params }
    method set-params(Mu $, @params) { @!params = @params }
    method reify-parameter(Mu $, Mu \param) { @!params[param.^param-pos] }
}

class Spit::Metamodel::EnumClass is Spit::Metamodel::Type {
    has @!children;

    method add_parent(Mu \type, Mu \parent) {
        callsame;
        if parent.HOW ~~ Spit::Metamodel::EnumClass {
            parent.^add_child(type);
        }
    }

    # XXX: @!children aint gonna survive multiple precompilations and
    # deserialisations so might need to rethink this for things like
    # declaring a custom OS in a module. But since we don't do
    # precompilation of Spit modules yet so not a problem.
    method add_child(Mu $,Mu \child) {
        @!children.push(child);
        Nil;
    }

    method types-in-enum(Mu \type) { type, |@!children.map(*.^types-in-enum).flat }

    method prmitive(Mu \type) { type }

    method lookup-by-str(Mu \type,Str:D $str) {
        type.^types-in-enum.first: { .^name.lc ~~ $str.lc };
    }

    method children(Mu $) { @!children.list }
}

class Spit::Metamodel::WhateverInvocant is Spit::Metamodel::Type {
    method needs-reification(Mu $) { True }
    method reify(Mu $, Mu \invocant-type) { invocant-type }

    method name(Mu \type) {
        "WhateverInvocant({type.^parents[0].^name})";
    }
}
