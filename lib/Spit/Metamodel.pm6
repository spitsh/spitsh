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

# Used when a Parameterized with a Parameterizable as its parameter is augmented.
# 1. class List[Elem-Type] {...}
# 2. class Pair[Key, Value] {...}
# 3. augment List[Pair] {
#        method values (-->List[Elem-Type[1]] ⟵) {...}
#    }
# 4. Then when you call .values on something typed as List[Pair[Str,Int]]
#    you'll get a List[Int]
class Spit::Metamodel::ParameterAt {...}

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
    # array indexed by SymbolType then name to SAST::VarDecl for package options ($Foo:bar)
    has @!options;

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

    method add_parent(Mu $,Mu \parent) {
        if parent ~~ Spit::Type {
            $!dispatcher.add-parent(parent.^dispatcher);
            $!primitive = parent.primitive if $!primitive.WHAT =:= Mu;
        }
        callsame;
    }

    method compose(Mu \type){
        $!dispatcher.compose;
        die "Primitive not set on {type.^name} at composition time" if $!primitive.WHAT =:= Mu;
        callsame;
        if not type.^is-primitive {
            # check that something contradictory hasn't been declared like:
            # class Foo is Int is Bool { }
            for type.^parents(:local).grep(Spit::Type) {
                .^primitive ~~ $!primitive or
                  SX.new(
                    message => "{.^name} is incompatible with {type.^name}'s other parents",
                    node => $!declaration
                  ).throw;
            }
        }
        my \we-invocant = $!whatever-invocant;
        if we-invocant !=:= Mu and not we-invocant.^is_composed {
            we-invocant.^add_parent(type);
            we-invocant.^compose;
        }
        nqp::decont(type);
    }

    method whatever-invocant(Mu $type) {
        if nqp::decont($!whatever-invocant) =:= Mu {
            $!whatever-invocant = Spit::Metamodel::WhateverInvocant.new_type();
        }
        $!whatever-invocant;
    }

    method parent-derived-from(Mu \type, Mu \target) {
        my $parameterized := (type, |type.^parents).first({
            .HOW ~~ Spit::Metamodel::Parameterized
            && (.^derived-from === target)
        });
        $parameterized || Nil;
    }

    method reify(Mu \type,|) { type }
    method reify-parameter(Mu \type, Mu \param) {
        type.^parent-derived-from(param.^param-of)\
            .^params[param.^param-pos];
    }
    method needs-reification(Mu $) { False }

    method package-options(Mu $) { @!options }

    method get-package-option(Mu \type, SymbolType $symbol-type, Str:D $name, :$match) {
        @!options[$symbol-type]{$name} //
          $match && SX.new(message => "No such variable for class {type.^name}", :$match).throw;
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
        # Foo[Str,Bool], Foo[Str,Str] etc. So we recursively find
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
    # The thing this is a parameter of.
    # given List[Elem-type], $!param-of would contain List for Elem-type
    has Spit::Type $!param-of;
    # The position within the parameter list ie 0 for Elem-type
    has $!param-pos;
    # The cache of 'param-at's
    has @!param-at-cache;

    method set-param-of(Mu $,Mu $!param-of,Int:D $!param-pos) { }
    method param-of(Mu $) { $!param-of }
    method param-pos(Mu $) { $!param-pos }

    method reify(Mu \param, Mu \invocant-type) {
        invocant-type.^reify-parameter(param);
    }
    method needs-reification(Mu $) { True }

    method param-at(Mu \param, Int $index) {
        with @!param-at-cache[$index] {
            $_
        } else {
            my \param-at = Spit::Metamodel::ParameterAt.new_type(name => "{param.^name}[$index]");
            param-at.^set-index($index);
            param-at.^set-parameter(param);
            param-at.^add_parent(param.^primitive);
            param-at.^compose;
            $_ = param-at;
            param-at;
        }
    }
}


class Spit::Metamodel::ParameterAt is Spit::Metamodel::Type {
    has Spit::Type $!parameter; # A Parameter
    has Int $!index;

    method reify(
        Mu \param-at,
        Spit::Type $invocant-type
    ) {
        # Get the first thing in the type hierarchy derived from
        # $!parameter.^param-of. e.g if this is a Elem-Type[0], we
        # need to find the first parent of the invocant that's a parameterized
        # List, like List[Pair[Str,Int]], so we can figure out that Elem-Type[0]
        # actually means Str.
        my $inner := $invocant-type\
          .^parent-derived-from($!parameter.^param-of)\
          .^params[$!parameter.^param-pos];

        if $inner.HOW ~~ Spit::Metamodel::Parameterized {
            $inner.^params[$!index];
        }
        else {
            $inner.^placeholder-params[$!index].primitive;
        }
    }

    method set-index(Mu $, Int $index) { $!index = $index }
    method set-parameter(Mu $, $!parameter) { }

    method needs-reification(Mu $) { True }
}

class Spit::Metamodel::Parameterized is Spit::Metamodel::Type {
    has @!params;
    has $!derived-from;

    method needs-reification(Mu $) {
        @!params.first(*.^needs-reification).so
    }
    method reify(Mu \type, Mu \invocant-type) {
        return type unless type.^needs-reification;
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

class Spit::Metamodel::WhateverContext is Spit::Metamodel::Type {
    method needs-reification(Mu $) { True }
    method reify(Mu $, Mu $i?, Spit::Type :$ctx!) { $ctx }
}

sub gen-type($name,\parent,:$metatype = Spit::Metamodel::Type,:$primitive) {
    my $type := $metatype.new_type(:$name);
    $type.^add_parent(parent) if parent;
    $type.^set-primitive($type) if $primitive;
    $type.^compose;
};

constant tAny is export  = gen-type('Any', Nil, :primitive);
constant tStr is export  = gen-type('Str', tAny, :primitive);
constant tInt is export  = gen-type('Int', tStr, :primitive);
constant tBool is export = gen-type('Bool', tStr, :primitive);
constant tEnumClass is export = gen-type('EnumClass',tStr, :primitive);
constant tRegex is export = gen-type('Regex', tStr);
constant tPattern is export = gen-type('Pattern', tStr);
constant tFD is export = gen-type('FD', tInt,);
constant tFile is export  = gen-type('File', tStr);
constant tOS is export  = gen-type('OS', tEnumClass, metatype => Spit::Metamodel::EnumClass);
constant tPID is export = gen-type('PID', tInt);
constant tWhateverContext = gen-type('WhateverContext',tStr, metatype => Spit::Metamodel::WhateverContext);
constant tJSON is export = gen-type('JSON', tStr, :primitive);

sub gen-param-type($name, @param-names, :$primitive) {
    my $param-type := Spit::Metamodel::Parameterizable.new_type(:$name);
    $param-type.^set-primitive($param-type) if $primitive;
    $param-type.^add_parent(tStr);

    for @param-names.kv -> $i, $name {
        my $param := Spit::Metamodel::Parameter.new_type(:$name);
        $param.^add_parent(tStr);
        $param.^set-param-of($param-type, $i);
        $param.^compose;
        $param-type.^placeholder-params.push($param);
    }

    $param-type.^compose;
}

constant tList is export = gen-param-type('List', ['Elem-Type'], :primitive);
constant tPair is export = gen-param-type('Pair', ['Key', 'Value'], :primitive);

constant %bootstrapped-types is export  = %(
    (tAny,tStr,tInt,tBool,tList,tRegex,tPattern,tEnumClass,tFD,tOS, tPID, tPair, tJSON)\
      .map({ .^name => $_ }).eager.Slip;
);
