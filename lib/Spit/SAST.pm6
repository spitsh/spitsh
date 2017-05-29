# Where all the SAST nodes are kept.
# Most of the have to be in the same file because they depend on each other.
need Spit::Exceptions;
use Spit::Constants;
need DispatchMap;
need Spit::SpitDoc;
use Spit::Stage2-Util;

use Spit::Metamodel;

class SAST::IntExpr   {...}
class SAST::Var       {...}
class SAST::Block     {...}
class SAST::Param     {...}
class SAST::Empty       {...}
class SAST::Return    {...}
class SAST::Signature {...}
class SAST::MethodCall {...}
class SAST::IVal      {...}
class SAST::BVal       {...}
class SAST::SVal {...}

class SAST::Blessed      {...}
class SAST::List {...}
class SAST::ClassDeclaration {...}
class SAST::Concat {...}
class SAST::PhaserBlock {...}
class SAST::Invocant {...}
class SAST::Type {...}
class SAST::RoutineDeclare { ... }
class SAST::Cmd {...}
class SAST::ACCEPTS {...}
class SAST::Itemize {...}

role SAST::Force {...}

sub lookup-type($name,:@params, Match :$match) is export {
    my $type := $*CURPAD.lookup(CLASS,$name, :$match).class;
    $type := $type.^parameterize(|@params) if @params;
    $type;
}

sub sastify($_, :$match!) is export {
    when Associative { .map: { .key => sastify(.value) } }
    when Positional  { .map: &sastify }
    when Spit::Type  { SAST::Type.new(class-type => $_,:$match) }
    when Int         { SAST::IVal.new(val => $_,:$match) }
    when Str         { SAST::SVal.new(val => $_,:$match) }
    when Bool        { SAST::BVal.new(val => $_,:$match) }
    default          { Nil }
}

role SAST is rw {
    has Match:D $.match is required is rw;
    has %.ann; # a place to put stuff that doesn't fit anywhere
    has $.stage2-done is rw;
    has $.stage3-done is rw;
    has $.cloned is rw;
    has Spit::Type $.ctx is rw; # The type context the object was put in in stage2
    has $.included is rw;
    has @.extra-depends;

    method do-stage2(Spit::Type \ctx,:$desc,|args){
        SX::BugTrace.new(
            desc => "do-stage2 called on {self.WHICH} twice",
            node => self,
            bt => Backtrace.new
        ). throw if $.stage2-done;
        SX::BugTrace.new(
            desc => "node of type {self.^name} has stage2 called with Spit::Type as context",
            node => self,
            bt => Backtrace.new
        ).throw if ctx === Spit::Type;
        $!ctx = ctx;
        my SAST:D $res = self.stage2(ctx,|args);
        $!stage2-done = True;
        $res = coerce $res,ctx,:$desc;
        $res;
    }

    method stage2($) { self }

    method new(Match :$match? is copy,|a) {
        if not $match {
            my $tmp = OUTER::CALLER::LEXICAL::<$/>;
            $match = $tmp // Nil;
        }
        self.bless(:$match,|a);
    }
    # A Bool is never the topic
    method topic($self is rw:) { $.type ~~ tBool ?? Nil !! return-rw $self }

    method assign-type { IMMUTABLE }
    method assignable  { self.assign-type !== IMMUTABLE }
    method compile-time { Nil }
    method gist { self.node-name }
    method spit-gist { self.gist }
    method node-name {
        if self ~~ SAST::Force {
            self.^name.subst(/^'SAST::'/,'')\
                .subst(/'SAST::Force'/,"Force({$.type.^name},{$.itemize ?? '$' !! '@'})")
        } else {
            self.^name.subst(/^'SAST::'/,'')
        }
    }
    method itemize { True }
    method depends { Empty }
    method child-deps { self.depends }
    method all-depends { |@.extra-depends, |self.depends  }
    method type {...} # The type for type checking
    method ostensible-type { self.type } # The the type that the thing looks like
    method deep-clone { self.clone }
    method deep-first(\needle) { self if self ~~ needle }
    method identity { $!cloned || self }

    # Convenience methods
    method stage2-node(\type,|args) {
        type.new(:stage2-done,:$.ctx,:$.match,|args);
    }

    method stage3-node(\type,|args) {
        type.new(
            :stage2-done,
            :stage3-done,
            :!cloned,
            :$.ctx,
            :$.match,
            |args,
        )
    }
    method is-invocant {
        self ~~ SAST::Var
        && (my $d := self.declaration) ~~ SAST::Invocant
        && $d
        || Nil;
    }
    method uses-Str-Bool {
        self.type.^find-spit-method('Bool') === tStr.^find-spit-method('Bool');
    }

    method make-new(\type,|args){
        type.new(
            :$.match,
            |args,
        );
    }

    # used in stage3 to replace one node with another in the AST. When
    # replacing one node for another you want preserve the type and
    # itemization of the node being replaced (and usually its context)
    method switch(SAST:D $self is rw: $b is copy, :$force-ctx = True) {
        if $b.type !=== $self.type or $b.itemize !=== $self.itemize {
            $b .= force($self.type, $self.itemize);
        }
        $b.extra-depends.append($self.extra-depends);
        $b.ctx = $self.ctx if $force-ctx;
        $self = $b;
    }

    method force($type, $itemize) {
        self does SAST::Force unless self ~~ SAST::Force;
        self.type = $type;
        self.itemize = $itemize;
        self;
    }
}

my role SAST::Force {
    has $.type is rw;
    has $.itemize is rw;
}

role SAST::Assignable {
    has SAST $.assign is rw;
    has SAST $.assign-mod is rw;

    method assign-type { ... }
}

# makes sure $node is ~~ $type.primative or coerces it to it OR throws a type exception
sub coerce(SAST:D $node, Spit::Type $target, :$desc) {
    my $target-prim = $target.primitive;
    X::AdHoc.new( payload => "{$node.^name} {try $node.gist} gave a literal Spit::Type type object").throw
        if $node.type === Spit::Type;
    X::AdHoc.new( payload => "{$node.^name} returned it's type as something that isn't a Spit::Type ({$node.type.^name}) ").throw
        if $node.type !~~ Spit::Type;

    if $node.type.primitive ~~ $target-prim {
        # all good
        $node;
    } else {
        if $node.type.^find-spit-method($target.^name) ||
           $node.type.^find-spit-method($target-prim.^name) -> $meth {
            # We got a coercer method, wrap this node in it and call it
            my $call = SAST::MethodCall.new(
                match => $node.match,
                name => $target-prim.^name,
                $node,
            );
            $call.set-declaration($meth);
            return $call.do-stage2($target-prim,:$desc);
        }
        else {
            # We need node to become a list. As long as the node matches the List's
            # element type we can just bless this node into a List[of-the-appropriate type]
            if $target ~~ tList and $node.type !~~ tList {
                my $elem-type := flattened-type($target);
                $node.stage2-node(
                    SAST::Blessed,
                    class-type => tListp($node.type),
                    coerce($node,$elem-type,:desc<list coercion>),
                );
            }
            # we lose
            else {
                SX::TypeCheck.new(
                    :$node,
                    :$desc,
                    got => $node.type.^name,
                    expected => $target-prim.^name,
                ).throw
            }
        }
    }
}

# XXX: why are there two? This can be done better.
role SAST::Dependable {
    has $.referenced is rw;
    has $.depended is rw;
    method dont-depend { False }
}
role SAST::Declarable does SAST::Dependable {
    has $.declared-in is rw;
    has SpitDoc:D @.docs;
    method symbol-type {...}
    method name {...}
    method bare-name { $.name }
}

role SAST::OSMutant {
    has $.mutated is rw;
    method mutate-for-os($os) {...}
}

class SAST::Children does SAST {

    method children { Empty }
    method auto-compose-children { @.children }
    method gist {
        "$.node-name$.gist-children";
    }

    method gist-children {
        if @.children {
            my $parent-pad = CALLERS::<$*gpad> || '';
            my $*gpad = $parent-pad ~ "  ";
            "\n$*gpad" ~ '- ' ~ @.children.map(*.gist).join("\n$*gpad" ~ '- ')
        }
    }

    method type { tAny }

    method child-deps {
        # XXX: THIS IS HORRIBLE AND HAS TO DIE ASAP. NEED TO USE LEXICAL ANALYSIS INSTEAD.
        (|@.children.map(*.child-deps).flat,|self.depends).grep({ $_ !~~ SAST::Param|SAST::Invocant });
    }

    method descend($self is rw: &block) {
        &block($self) && return True;
        for $self.children {
            when SAST::Children { .descend(&block) && return True }
            default { &block($_) && return True }
        }
        return False;
    }

    method deep-clone(|c){
        my \ret := self.clone(|c);
        for ret.children {
            $_ .= deep-clone;
        }
        ret;
    }

    method deep-first(\needle){
        return self if self ~~ needle;
        for @.children {
            .return with .deep-first(needle);
        }
    }
}

class SAST::MutableChildren  is SAST::Children {
    has SAST:D @.nodes handles <append prepend push pop shift unshift AT-POS elems>;

    method children { @!nodes }
    method new(*@nodes,Match :$match? is copy,|a) {
        my $tmp = CALLER::LEXICAL::<$/>;
        $match ||= $tmp // Nil;
        self.bless(:@nodes,:$match,|a);
    }

    method clone(|c){ callwith(|c,:@!nodes) }
}

class SAST::CompUnit is SAST::Children {
    has SAST::Block:D $.block is required is rw;
    has $.depends-on is rw; # A Spit::DependencyList
    has @.phasers;
    has @.exported;
    has $.name is required;

    method do-stage2 {
        my $*CU = self;
        $!block .= do-stage2(tAny,:!auto-inline);
        self.stage2-done = True;
        self;
    }

    method children { $!block, }

    method type { tAny }

    multi method export(SymbolType $type,$name,$value)  {
        @!exported[$type]{$name} = $value;
    }

    multi method export(SAST::Declarable:D $d) {
        self.export($d.symbol-type,$d.name,$d);
    }

    method gist { callsame() ~ ("\ndepends:\n" ~ $!depends-on.gist if $!depends-on) ~ "\n" }
}



class SAST::Var is SAST::Children does SAST::Assignable {
    has $.name is required;
    has Sigil:D $.sigil is required;
    has $.declaration;

    method symbol-type {
        given $!sigil {
            when '$' { SCALAR }
            when '@' { ARRAY  }
            when '&' { SUB    }
        }
    }

    method assign-type { $!sigil eq '@' ?? LIST-ASSIGN !! SCALAR-ASSIGN }

    method stage2($ctx) is default {
        with $.assign-mod {
            my $clone = self.declaration.gen-reference(:$.match);
            .append($clone,$.assign);
            $.assign = $_;
        }
        $_ .= do-stage2(self.type,:$.desc) with $.assign;
        self;
    }

    method gist { $.node-name ~ "($.spit-gist)" ~ (' = ' if $.assign) ~ $.gist-children }

    method spit-gist { "$!sigil$!name" }

    method declaration is rw {
        $!declaration //= $*CURPAD.lookup(self.symbol-type,$!name,:$.match);
    }

    method type { self.declaration.type }

    method children { list $.assign // Empty  }

    method depends { $.declaration, }

    method is-option  { $!name.starts-with('*') }

    method gen-reference(:$match!,|c){
        SAST::Var.new(:$.name,:$.sigil,:$match,:$.declaration,|c);
    }

    method desc { "Assignment to $.spit-gist" }

    method itemize { itemize-from-sigil($!sigil) }
}

class SAST::VarDecl is SAST::Var does SAST::Declarable is rw {
    has Spit::Type $.type;
    has Spit::Type $.decl-type;
    has $.dont-depend is rw;

    method stage2(SAST::VarDecl:D: $ctx) is default {
        figure-out-var-type($.sigil, $!type, $!decl-type, :$.assign, :$.desc);
        self;
    }
    method bare-name  { $.name.subst(/^<[*?]>/,'') }
    method dont-depend is rw { $!dont-depend }
    method depends { Empty }
    method declaration { self }
}

class SAST::EnvDecl is SAST::VarDecl { }

# MaybeReplace represents a conditional topic $_ like thing. If its
# assignment is pure (compile-time/variable) then references will just
# inline themselves during composition. Otherwise the references stick
# and during compilation it turns into a real $_ variable in the
# shell.
class SAST::MaybeReplace is SAST::VarDecl {
    has @.references;

    method replace-with {
        given $.assign {
            when .compile-time !~~ Nil { $_ }
            when SAST::Var|SAST::Param|SAST::Invocant { $_ }
            default { Nil }
        }
    }

    method add-ref($ref) {
        @!references.push: $ref;
    }
}

class SAST::ConstantDecl is SAST::VarDecl {
    method inline-value {
        self.assign if self.assign andthen .compile-time !~~ Nil;
    }
    method assign-type { IMMUTABLE }
}

class SAST::Stmts is SAST::MutableChildren does SAST::Dependable {
    has Bool:D $.auto-inline is rw = True;

    method stage2($ctx,:$desc,:$loop,:$!auto-inline = True) is default {
        my $last-stmt := self.last-stmt;
        for @.children {
            $_ .= do-stage2(tAny) unless $_ =:= $last-stmt;
        }
        if $last-stmt {
            if $ctx !=== tAny {
                $last-stmt = SAST::Return.new(val => $last-stmt,match => $last-stmt.match,:$loop)
            }
            $last-stmt .= do-stage2($ctx,:desc<return value of block>);
        }
        self;
    }

    method returns is rw {
        with self.last-stmt {
            when SAST::Return { $_ }
            default { Nil}
        }
    }

    method last-stmt is rw {
         @.children.reverse.first({ $_ !~~ SAST::PhaserBlock });
    }

    method one-stmt is rw {
        if @.children == 1 {
            given @.children[0] {
                when SAST::Return { .val }
                default { $_ }
            }
        } else {
            Nil
        }
    }

    method type {
        if self.returns -> $_ {
            .type
        } else {
            tAny;
        }
    }

    method itemize { self.last-stmt  andthen .itemize or False }
}

class SAST::Block is SAST::Stmts {
    has @.symbols;
    has $.outer is rw;

    method stage2($ctx,|c) {
        my $*CURPAD = self;
        callsame;
    }

    multi method lookup(SymbolType $type,Str:D $name,Match :$match) {
        @!symbols[$type]{$name}
        || self.outer.?lookup($type,$name,:$match)
        || ( $match && SX::Undeclared.new(
            :$name,
            :$type
            :$match,
        ).throw)
        || Nil
    }

    multi method lookup(SAST::Declarable:D $sast) {
        samewith($sast.symbol-type,$sast.name,match => $sast.match)
    }

    method declare(SAST::Declarable:D $sast) {
        with @!symbols[$sast.symbol-type]{$sast.name} {
            SX::Redeclaration.new(
               name => $sast.name,
               type => $sast.symbol-type,
               match => $sast.match,
               orig-match => .match
            ).throw;
        } else {
            $sast.declared-in = self;
            $_ = $sast;
        }
    }

    method symbol(SymbolType $type,Str:D $name) {
        @!symbols[$type]{$name};
    }

    method gist {
        $.node-name ~ " --> {$.type.^name}" ~ $.gist-children;
    }

    method type {
        my $*CURPAD = self;
        callsame;
    }
}

class SAST::PhaserBlock is SAST::Children {
    has SAST::Stmts:D $.block is required;
    has Spit-Phaser $.stage is required;

    method stage2 ($) { $!block .= do-stage2(tAny,:!auto-inline); self }
    method children { $!block, }
    method type { tAny }
}

class SAST::Return is SAST::Children {
    has $.val is rw;
    has $.return-by-var is rw;
    has $.loop is rw;
    method stage2($ctx) is default {
        self.val .= do-stage2($ctx,:desc("return value didn't match block's return type"));
        self;
    }
    method type { $!val.type }
    method children { $!val, }
    method itemize { $!val.itemize }
}

# Array element
class SAST::Elem is SAST::MutableChildren does SAST::Assignable {
    has SAST $.index is required;
    has Spit::Type $.index-type is required;

    method assign-type { SCALAR-ASSIGN }

    method stage2($ctx) {
        SX::NYI.new(feature => 'element assignment modifiers',node => $_).throw with $.assign-mod;
        my $method-end = $!index-type ~~ tInt ?? 'pos' !! 'key';
        my $method = do if $.assign {
            SAST::MethodCall.new(
                name => "set-$method-end",
                pos => ($!index,$.assign),
                $.elem-of,
                :$.match
            )
        } else {
            SAST::MethodCall.new(
                name => "at-$method-end",
                pos => ($!index),
                $.elem-of,
                :$.match
            )
        }

        $method .= do-stage2($ctx);
    }

    method gist { $.elem-of.gist ~ '[' ~ $!index.gist ~ ']' }
    method stage2-done { False } # This should be gone after stage2
    method elem-of is rw { @.nodes[0] }
    method children { $.elem-of,$!index, ($.assign // Empty) }
    method spit-gist { $.elem-of.spit-gist ~ '[' ~ $!index.spit-gist ~ ']' }
}

class SAST::Cmd is SAST::MutableChildren is rw {
    has SAST $.pipe-in;
    has SAST @.in;
    has SAST @.write;
    has SAST @.append;
    has SAST %.set-env;
    has $.silence is rw;

    method stage2($ctx) is default {
        $_ .= do-stage2(tStr) for ($!pipe-in,|@.nodes,|%!set-env.values).grep(*.defined);

        for |@!write,|@!append,|@!in <-> $lhs, $rhs {
            $lhs  .= do-stage2(tFD, :desc<redirection left-hand-side>);
            $rhs  .= do-stage2(tStr,:desc<redirection right-hand-side>);
        }
        if not ($!pipe-in and (@!write || @!append) or @.nodes) {
            self.make-new(SX,message => ‘command can't be empty’).throw;
        }

        if (my $invocant = ($!pipe-in andthen .is-invocant)) and $*no-pipe {
            $invocant.cancel-pipe-vote;
        }
        self;
    }

    method children {
        grep *.defined, $!pipe-in, |@.nodes, |@!in, |@!write, |@!append, |%!set-env.values;
    }

    method clone(|c) { callwith(|c,:@!write,:@!append,:@!in,:%!set-env) }

    method type { $.ctx !=== tAny ?? $.ctx !! tStr }
}

class SAST::Coerce is SAST::MutableChildren {
    has Spit::Type $.to is required;
    method type { $!to }
    method stage2 ($) {
        self[0] .= do-stage2($!to);
        self[0];
    }
    method gist { $.node-name ~ "({$!to.name})" ~ $.gist-children }
}

class SAST::Cast is SAST::MutableChildren {
    has Spit::Type $.to is required;

    method type { $!to }
    method stage2 ($ctx) {
        # Type casting blocks outer context propagation to avoid
        # coercions happening to the casted object. The casted to type
        # will handle how to react in the given context.
        self[0] .= do-stage2: do given $ctx {
            when tStr  { tStr  }
            default    { tAny  }
        };
        self;
    }
    method gist { $.node-name ~ "({$!to.name})" ~ $.gist-children }
}

# Negation
class SAST::Neg is SAST::MutableChildren {
    method type { tBool }

    method stage2 ($) {
        self[0] .= do-stage2(tBool);
        self;
    }

    method topic is rw { self[0].topic }
}

# Negative number
class SAST::Negative is SAST::MutableChildren {
    has $.as-string;
    method type { self[0].type }
    method stage2 ($ctx) {
        $!as-string = SAST::Concat.new(SAST::SVal.new(val => '-',:$.match,:stage2),self[0],:$.match,:stage2);
        self[0] .= do-stage2(tInt);
        self;
    }
}

class SAST::RoutineDeclare is SAST::Children does SAST::Declarable does SAST::OSMutant {
    has Str $.name is required;
    has SAST::Signature $.signature is rw;
    has Spit::Type $.return-type is rw = tAny;
    has @.os-candidates is rw;
    has $.is-native is rw;
    has $.chosen-block is rw;
    has $.return-by-var is rw;
    has $.impure is rw;
    has $.no-inline is rw;

    method symbol-type { SUB }

    method gist {
        $.node-name ~ "($!name)" ~ $.gist-children;
    }
    method spit-gist { "sub {$.name}\({$.signature.spit-gist})" }

    method stage2($) {
        $!signature.do-stage2(tAny);
        # make os-candidates into a list of writable pairs
        @!os-candidates .= flatmap: -> $os,$block { cont-pair $os,$block };
        for @.os-candidates {
            .value .= do-stage2(
                $!is-native ?? tAny !! $.return-type,
                :!auto-inline,
                :desc("return value of $.spit-gist didn't match return type of $!name"));
            .return-by-var = $!return-by-var with .value.returns;
        }
        self;
    }
    method type { tAny }

    method mutate-for-os(Spit::Type $os) {
        $!chosen-block = self.block-for-os($os) // False;
        Nil;
    }

    method children {
        $!signature, ($!chosen-block // |@!os-candidates.map(*.value) || Empty);
    }
}

class SAST::MethodDeclare is SAST::RoutineDeclare {
    has $.rw is rw;
    # The type of the class declaration it was declared in
    has Spit::Type $.class-type is rw;
    has SAST::Invocant $.invocant is rw;

    method static { !$!invocant }

    method spit-gist { "method {$.name}\({$.signature.spit-gist})" }

    method stage2($) {
        $.return-type = $.class-type if $!rw;
        $!invocant andthen $_ .= do-stage2(tAny);
        $.signature.invocant = $!invocant;
        $!invocant.cancel-pipe-vote if $.impure;
        nextsame;
    }

    method reified-return-type($invocant-type) {
        my $return-type := self.return-type;
        if $return-type.^needs-reification {
            $return-type.^reify($invocant-type);
        } else {
            $return-type
        }
    }

    method reified-signature($invocant-type) {
        $.signature.reify($invocant-type);
    }

    method block-for-os($os) {
        $!class-type.^dispatcher.get(self.name,$os);
    }

    method declarator { 'method' }

    method children { |callsame, ($!invocant // Empty) }
}


class SAST::SubDeclare is SAST::RoutineDeclare {
    has $!dispatcher;

    method dispatcher {
        $!dispatcher //= DispatchMap.new(tmp => self.os-candidates).compose;
    }
    method block-for-os($os) {
        self.dispatcher.get('tmp',$os);
    }

    method declarator { 'sub' }
}

class SAST::Call  is SAST::Children {
    has SAST:D %.named;
    has SAST:D @.pos;
    has SAST::RoutineDeclare $.declaration is rw;
    has Str:D $.name is required;

    method stage2($ctx) is default {
        # defined in Spit::Stage2-Util
        do-stage2-call(self, $.declaration);
        self;
    }

    # gets a list of named params from the declaration and pairs them
    # up with the corresponding named args
    method param-arg-pairs {
        %!named.kv.map: -> $name,$arg {
            do if $.declaration.signature.named{$name} -> $param {
                $param => $arg
            }
        }
    }

    method type {
        self.declaration.return-type;
    }

    method declaration is rw { $!declaration //= self.find-declaration;}
    method set-declaration(SAST::RoutineDeclare:D $!declaration) { }

    method clone(|c){ callwith(|c,:@!pos,:%!named) }

    method depends { $.declaration, }

    method signature { self.declaration.signature }

    method itemize { $.type !~~ tList }

    method gist { $.node-name ~ "($!name)" ~ $.gist-children }

    method fill-in-defaults {
        |(self.signature.pos-with-defaults.map: -> $pos {
            without @!pos[$pos.ord] {
                $_ = $pos.default.deep-clone;
            }
        }),
        |(self.signature.named-with-defaults.map: -> $named {
            without %!named{$named.name} {
                $_ = $named.default.deep-clone;
            }
        });
    }
}

class SAST::MethodCall is SAST::Call is SAST::MutableChildren {
    has $!signature;
    has $!type;
    has $.topic;

    method invocant is rw { self[0] }
    method type {
        $!type ||= self.declaration.reified-return-type($.invocant.ostensible-type);
    }
    method signature {
        $!signature //= self.declaration.reified-signature($.invocant.ostensible-type);
    }

    method stage2($ctx) {
        my $is-type = $.invocant.WHAT === SAST::Type;
        if not $.invocant.stage2-done {
            $.invocant .= do-stage2: $is-type ?? tAny !! tStr;
        }
        if not $.declaration.static and $is-type and not $.invocant.ostensible-type.enum-type {
            SX.new(message => q|Instance method called on a type.|,:$.match).throw;
        }

        if not $is-type and $*no-pipe and (my $outer-invocant = $.invocant.is-invocant) {
            $outer-invocant.cancel-pipe-vote;
        }
        callsame;
    }

    method find-declaration {
        $.invocant.ostensible-type.^find-spit-method($.name,:$.match);
    }

    method children {
        ($.invocant unless $.declaration.static), |@.pos, |%.named.values
    }

    method topic($self is rw:)  is rw {
        $!topic or do if $.type ~~ tBool {
            $.invocant.topic
        } else {
            $self;
        }
    }

    method spit-gist { ".$.name" ~ "\(...)" }
}

class SAST::SubCall is SAST::Call {

    method find-declaration {
        $*CURPAD.lookup(SUB,$.name,:$.match);
    }

    method children { |@.pos,|%.named.values }

    method spit-gist { $.name ~ "(...)" }
}
role SAST::ShellPositional {
    method shell-position {...}
}

class SAST::Invocant does SAST does SAST::Declarable does SAST::ShellPositional {
    has $.class-type is required;
    # if pipe-vote ends up > 0 at compilation $self gets piped
    has Int $.pipe-vote is rw;
    has $.signature is rw;
    has Int $!yes-voted;
    has $!vote-canceled;
    # You can only have one yes vote
    method vote-pipe-yes { $!pipe-vote++ unless $!vote-canceled or $!yes-voted++ }
    method vote-pipe-no  { $!pipe-vote-- unless $!vote-canceled }
    method start-pipe-vote    { $!pipe-vote = 1 }
    method cancel-pipe-vote   { $!pipe-vote = 0; $!vote-canceled = True; }
    method piped { $!pipe-vote andthen $_ > 0 }
    method name { 'self' }
    method symbol-type { SCALAR }
    method gist { $.node-name ~ "($.spit-gist)" }
    method spit-gist { '$self' }
    method type { $!class-type }
    method dont-depend { True }
    method stage2 ($) { self }
    method itemize { True }
    method shell-position { 1 }
}

class SAST::Param does SAST does SAST::Declarable {
    has Str:D $.name is required;
    has Sigil:D $.sigil is required;
    has $.signature is rw;
    has $.decl-type;
    has $.type is rw;
    has SAST $.default;
    has $.optional is rw;
    has $.slurpy;

    method TWEAK(|){
        # $ slurpies are still lists so pretend it's @ for type determination
        figure-out-var-type(($!slurpy ?? '@' !! $!sigil),
                            $!type, $!decl-type);
    }

    method stage2 ($) {
        $_ .= do-stage2($!type, :desc("parameter {$.spit-gist}'s default")) with $!default;
        self
    }
    method symbol-type { symbol-type-from-sigil($!sigil) }
    method dont-depend { True }
    method optional { $!optional or ?$!default }
    method gist { $.node-name ~ "($.spit-gist)" }
    method itemize { itemize-from-sigil($!sigil) }
}


class SAST::PosParam is SAST::Param does SAST::ShellPositional {
    has Int $.ord is rw;

    method spit-gist { ('*' if $.slurpy) ~ "$.sigil$.name" }
    method shell-position {
        ~($.ord + (($.signature.invocant andthen !.piped) ?? 1 !! 0 ) + 1);
    }
}

class SAST::NamedParam is SAST::Param {
    method spit-gist {  ":$.sigil$.name" }
}

class SAST::Signature is SAST::Children {
    has SAST::PosParam:D @.pos;
    has SAST::NamedParam:D %.named;
    has SAST::Invocant $.invocant is rw;
    has SAST::PosParam:D @.pos-with-defaults;
    has SAST::NamedParam:D @.named-with-defaults;

    method stage2 ($) {
        my $optional-found;
        for @!pos.kv -> $i,$p is rw {
            if $optional-found and not $p.optional {
                SX.new(message =>
                  “Can't put required parameter {$p.spit-gist} after optional parameters”
                ).throw;
            }
            if $p.optional {
                $optional-found = True;
                @!pos-with-defaults.push($p) if $p.default;
            }
            $p.ord = $i;
            $p.signature = self;
            $p .= do-stage2(tAny);
        }
        $!invocant andthen .signature = self;
        for %!named.values {
            $_ .= do-stage2(tAny);
            @!named-with-defaults.push($_) if .default;
        }
        self;
    }

    method children { ($!invocant // Empty), |@.params }
    method params { |@!pos, |%!named.values}
    method gist { $.node-name ~ '(' ~ $.spit-gist ~ ')' }
    method type { tAny }
    method clone(|c) {
        my \cloned = callwith(|c, :@!pos, :%!named);
        .signature = cloned for cloned.children;
        cloned;
    }

    method spit-gist {
        ~ @.children.map({ "{.type.name} {.spit-gist}" }).join(", ");
    }

    method reify($invocant-type) {
        if $invocant-type.HOW ~~ Spit::Metamodel::Parameterized
           and @.children.first(*.type.^needs-reification)
        {
            my $copy = self.clone;
            for $copy.params {
                $_ .= clone;
                .type = .type.^reify($invocant-type);
            }
            $copy;
        } else {
            self;
        }
    }

    method slurpy-param {
        (my $last = @!pos.tail).?slurpy ?? $last !! Nil;
    }
}

class SAST::ClassDeclaration does SAST::Declarable is SAST::Children {
    has Spit::Type $.class is required;
    has SAST::Block $.block is rw;

    method symbol-type { CLASS }
    method name { self.class.^name }
    method type { tAny }
    method children { ($!block // Empty),  }
    method stage2 ($) {
        $_ .= do-stage2(tAny,:!auto-inline) for self.children;
        self;
    }
}

class SAST::IntExpr is SAST::MutableChildren {
    has Str:D $.sym is required;

    method type { tInt }

    method stage2($) {
        $_ .= do-stage2(tInt,:desc("arguments to $!sym operation must be Ints")) for @.children;
        self;
    }

    method gist {
        $.node-name ~ "($!sym)" ~ $.gist-children;
    }
}

class SAST::Cmp is SAST::MutableChildren {
    has Str:D $.sym is required;

    method stage2($) {
        my $type = do given $!sym {
            when '>='|'<='|'<'|'>'|'=='|'!=' { tInt }
            default { tStr }
        }
        $_ .= do-stage2($type,:desc("arguments to $!sym comparison must be {$type.^name}")) for @.children;
        self;
    }

    method type { tBool }
}

class SAST::Increment is SAST::MutableChildren {
    has $.pre;
    has $.decrement = False;
    has $.amount = 1;

    method stage2($) {
        SX::Assignment-Readonly.new(match => self.match).throw if self[0].assign-type ~~ IMMUTABLE;
        @.children[0] .= do-stage2(tInt);
        self;
    }

    method type { tInt }

    method gist { $.node-name ~ "({$!decrement ?? '-' !! '+' }=$!amount)" ~ $.gist-children }
}

enum JunctionContext <NEVER-RETURN RETURN-WHEN-FALSE RETURN-WHEN-TRUE JUST-RETURN>;

# Represents the LHS or RHS of junctions where its value
# might need to returned as the value of the entire expression
# $.when it's True of False.
class SAST::CondReturn is SAST::Children  {
    has Bool:D $.when is required;
    has $.val is required;
    has $.Bool-call is rw;

    method stage2($ctx) {
        $!val .= do-stage2($ctx);
        if $!val.type !~~ tBool {
            $!Bool-call = SAST::MethodCall.new(
                match => $!val.match,
                name => 'Bool',
                $!val.clone,
            ).do-stage2(tBool);
        }
        self;
    }

    method children { $!val,($!Bool-call // Empty) }
    method auto-compose-children { $!val, }
    method type { $!val.type }
    method gist { $.node-name ~ "($!when)" ~ $.gist-children }
}

class SAST::Junction is SAST::MutableChildren {
    has $.dis; #disjunction(||) or conjunction(&&)
    has $.RHS-junct-ctx;
    has $.LHS-junct-ctx;

    method stage2 ($ctx,:$junct-ctx is copy) {
        # NEVER RETURN: We only care about it in Bool ctx -- never return its value.
        # JUST RETURN: We only care about its value.
        # RETURN-WHEN-TRUE: We care about its value when it's Bool ctx is True.
        # RETURN-WHEN-FALSE: The converse
        given $junct-ctx {
            when NEVER-RETURN {
                $!LHS-junct-ctx = $!RHS-junct-ctx = NEVER-RETURN;
            }
            when $ctx === tAny {
                # Tell the LHS to be a Bool and pass on Any context to RHS.
                $!LHS-junct-ctx = NEVER-RETURN;
                $!RHS-junct-ctx = JUST-RETURN;
            }
            when { ! .defined or $_ == JUST-RETURN } {
                $!LHS-junct-ctx = $!dis ?? RETURN-WHEN-TRUE !! RETURN-WHEN-FALSE;
                $!RHS-junct-ctx = JUST-RETURN;
            }
            when RETURN-WHEN-TRUE  {
                if $!dis {
                    $!LHS-junct-ctx = RETURN-WHEN-TRUE;
                    $!RHS-junct-ctx = RETURN-WHEN-TRUE;
                } else {
                    $!LHS-junct-ctx = NEVER-RETURN;
                    $!RHS-junct-ctx = RETURN-WHEN-TRUE;
                }
            }
            when RETURN-WHEN-FALSE {
                if ! $!dis {
                    $!LHS-junct-ctx = RETURN-WHEN-FALSE;
                    $!RHS-junct-ctx = RETURN-WHEN-FALSE;
                } else {
                    $!LHS-junct-ctx = NEVER-RETURN;
                    $!RHS-junct-ctx = RETURN-WHEN-FALSE;
                }
            }
        }


        for flat @.children Z ($!LHS-junct-ctx,$!RHS-junct-ctx) <-> $child,$junct-ctx {
            if $child ~~ SAST::Junction {
                $child .= do-stage2($ctx,:$junct-ctx);
            } else {
                given $junct-ctx {
                    when NEVER-RETURN { $child .= do-stage2(tBool)  }
                    when JUST-RETURN  { $child .= do-stage2($ctx)   }
                    when RETURN-WHEN-TRUE {
                        $child = SAST::CondReturn.new(
                            when => True,
                            val => $child,
                            match => $child.match
                        ).do-stage2($ctx);
                    }
                    when RETURN-WHEN-FALSE {
                        $child = SAST::CondReturn.new(
                            when => False,
                            val => $child,
                            match => $child.match
                        ).do-stage2($ctx);
                    }
                }
            }
        }

        self;
    }

    method type {
        my @types = (self[0].type if $!LHS-junct-ctx !== NEVER-RETURN),
                    (self[1].type if $!RHS-junct-ctx !== NEVER-RETURN);
        if @types {
            derive-common-parent @types;
        } else {
            tBool;
        }
    }

    method gist { $.node-name ~ '(' ~ ($!dis ?? '||' !! '&&') ~ ')' ~ $.gist-children }
}

class SAST::Ternary is SAST::Children {
    has SAST:D $.cond is required;
    has SAST:D $.on-false is required;
    has SAST:D $.on-true is required;

    method type {
        derive-common-parent($!on-false.type,$!on-true.type);
    }

    method stage2($ctx) {
        $!cond .= do-stage2(tBool);
        $_ .= do-stage2($ctx) for $!on-true,$!on-false;
        self;
    }

    method children { $!cond,$!on-true,$!on-false }
}

class SAST::Pair is SAST::MutableChildren {
    has $.type;

    method type { $!type ||= tPairp(|@.children.map(*.type)) }
    method stage2($) {
        $_ .= do-stage2(tStr) for @.children;
        self;
    }
    method key { self[0] }
    method value { self[1] }
}

class SAST::List is SAST::MutableChildren {
    has $.type;
    method type {
        $!type ||= do {
            my $base-type = derive-common-parent @.children.map: { .type.&flattened-type }
            tListp($base-type);
        }
    }
    method elem-type { flattened-type(self.type) }

    method stage2($ctx) {
        return self.make-new(SAST::Empty).do-stage2($ctx) unless @.children;
        $_ .= do-stage2($ctx ~~ tList ?? $ctx !! tStr) for @.children;
        self;
    }

    method compile-time {
        list do for @.children {
            return Nil unless .compile-time.defined;
            $_;
        }
    }
    method itemize { False }
}


role SAST::CompileTimeVal does SAST {
    method compile-time { $.val }
    method gist { $.node-name ~ "({$.val})" }
    method stage2 ($) { self }
}

class SAST::IVal does SAST::CompileTimeVal {
    has Int:D $.val is required is rw;
    method compile-time { $!val }
    method type { tInt }
}

class SAST::SVal does SAST::CompileTimeVal {
    has Str:D $.val is required is rw;
    method type { tStr }
    method compile-time { $!val }
}

class SAST::BVal does SAST::CompileTimeVal {
    has Bool:D $.val is required is rw;
    method type { tBool }
    method compile-time { $!val }
    # method stage2 ($ctx where { $_ ~~ tInt }) {
    #     SAST::IVal.new(val => +$!val,:$.match).do-stage2($ctx);
    # }
}

class SAST::Concat is SAST::MutableChildren {
    method type { tStr }
    method compile-time {
        my @ct = @.children.map(*.compile-time);
        if @ct.all.defined {
            @ct.map({
                when Bool { .so ?? '1' !! '' }
                default   { .Str }
            }).join;
        } else {
            Nil;
        }
    }
    method stage2($) {
        $_ .= do-stage2(tStr) for @.children;
        self
    }
}

sub dollar_(Match :$match!,*%_) {
    SAST::MaybeReplace.new(
        name => '_',
        :$match,
        sigil => '$',
        :dont-depend,
        |%_,
    );
}

sub generate-topic-var(:$var! is rw,:$cond! is rw,:@blocks!) {
    if $cond.topic <-> $topic-container {
        $var //= dollar_(match => $cond.match);
        $var.decl-type ||= $topic-container.type;
        $var .= do-stage2(tAny);
        $var.assign = $topic-container;
        $topic-container = $var.gen-reference(match => $topic-container.match).do-stage2(tAny);
        .declare($var) for @blocks;
    } elsif $var {
        SX.new(message => "Illegal declaration of topic variable {$var.spit-gist}. " ~
                          "Condition has no topic.", node => $var).throw;
    }
}

class SAST::If is SAST::Children is rw {
    has SAST:D $.cond is required is rw;
    has SAST::Block $.then is rw;
    has SAST $.else is rw;
    has SAST::MaybeReplace $.topic-var;
    has $.when;

    method stage2($ctx) is default {
        my $desc;
        if $!when {
            $!cond = self.make-new(
                SAST::ACCEPTS,
                (
                    $*CURPAD.lookup(SCALAR,'_') ??
                    # It's valid to use 'when' when $_ doesn't
                    # exist. So just set it to False by default.
                    SAST::Var.new(sigil => '$',name => '_', match => $!cond.match) !!
                    SAST::BVal.new(val => False, match => $!cond.match)
                ),
                $!cond,
            ).do-stage2(tBool);
            $desc = 'when block return value';
        } else {
            $!cond .= do-stage2(tBool,:desc<If/unless condition>);
            generate-topic-var(
               var => $!topic-var,
               blocks => ($!then, ($!else if $!else ~~ SAST::Block:D)),
               :$!cond
            );
            $desc = 'if/unless block return value';
        }
        $_ .= do-stage2($ctx,:$desc,:!auto-inline) for $!then,($!else // Empty);
        self;
    }

    method children {
        $!cond,$!then,($!topic-var // Empty),($!else // Empty)
    }
    method auto-compose-children {
        # Don't auto-compose else. If chains need to be walked from top to bottom.
        $!cond,$!then,($!topic-var // Empty)
    }
    method type { derive-common-parent($!then.type, ($!else.type if $!else)) }

    method itemize { False }
}

class SAST::While is SAST::Children {
    has SAST:D $.cond is required is rw;
    has SAST::Block $.block is rw;
    has $.until;
    has SAST::MaybeReplace $.topic-var;
    has $!type;

    method stage2($ctx) {
        # Because loops are re-entrant you can't pipe to the method if its
        # invocant is inside one of them.
        my $*no-pipe = True;
        $!cond .= do-stage2(tBool,:desc<while conditional>);
        generate-topic-var(var => $!topic-var,:$!cond,blocks => ($!block,));
        $!block .= do-stage2($ctx,:desc<while block return value>,:loop,:!auto-inline);
        self;
    }
    method children { $!cond,$!block,($!topic-var // Empty) }
    method type { $!type ||= tListp($!block.type) }
    method itemize { False }
}

class SAST::Given is SAST::Children is rw {
    has SAST:D $.given is required;
    has SAST $.block is required;
    has SAST::MaybeReplace $.topic-var;

    method stage2($ctx) {
        $!topic-var = dollar_(match => $!given.match,assign => $!given,:dont-depend);
        $!topic-var .= do-stage2(tAny);
        $!block.declare($!topic-var);
        $!block .= do-stage2($ctx);
        self;
    }

    method children { $!block,$!topic-var }

    method type { $!block.type }
}

class SAST::Loop is SAST::Children is rw {
    has SAST::Block $.block;
    has SAST $.init;
    has SAST $.cond;
    has SAST $.incr;
    has $!type;

    method stage2($ctx) {
        $!init  andthen $_ .= do-stage2(tAny);
        $!cond orelse $_ = SAST::BVal.new(:val, :$.match);
        $!cond .= do-stage2(tBool);
        $!block .= do-stage2($ctx, :loop, :!auto-inline);
        $!incr andthen $_ .= do-stage2(tAny);
        self;
    }

    method children { grep *.defined, $!init, $!cond, $!incr, $!block }

    method type { $!type ||= tListp($!block.type) }
    method itemize { False }
}

class SAST::For is SAST::Children {
    has SAST::Block $.block is rw;
    has SAST:D $.list is required;
    has SAST::VarDecl $.iter-var;
    has $!type;

    method stage2($ctx) {
        $!list .= do-stage2(tList);

        without $!iter-var {
            $_ = SAST::VarDecl.new(
                name => '_',
                match => $!list.match,
                sigil => '$',
                decl-type => $!list.elem-type,
                :dont-depend,
            );
        }
        $!iter-var.do-stage2(tAny);
        $!block.declare: $!iter-var;
        my $*no-pipe = True;
        $!block .= do-stage2($ctx, :loop, :!auto-inline);
        self;
    }

    method children { $!list,$!block,$!iter-var }
    method type { $!type ||= tListp($!block.type) }
    method itemize { False }
}

class SAST::Empty does SAST {
    method type { tListp($.ctx) }
    method stage2 ($) { self }
    method itemize { False }
    method compile-time { () }
}

class SAST::Type does SAST {
    has Str $.class-name;
    has Spit::Type $.class-type;
    has @.params;

    method class-type {
        $!class-type ||= lookup-type($!class-name, :@!params, :$.match);
    }

    method ostensible-type { self.class-type }

    method stage2($ctx) {
        if self.class-type.enum-type  {
            self;
        } elsif $ctx ~~ tStr {
            SAST::SVal.new(val => self.class-type.^name,:$.match).do-stage2($ctx);
        } else {
            self;
        }
    }

    method type { self.class-type.enum-type ?? self.class-type !! tAny }
    method gist { $.node-name ~ "({$.class-name || $.class-type.name})" }
    method compile-time { self.class-type }
    method declaration { $.class-type.^declaration }
}

class SAST::Blessed is SAST::MutableChildren is SAST::Type {

    method type { self.class-type }

    method stage2 ($ctx) {
        SX.new(node => self,
               message => "Can't bless something with type $.class-name because it doesn't have a primitive").throw
        unless self.type.primitive;

        if self.class-type.enum-type {
            self[0] .= do-stage2(tStr);
            if self[0].compile-time -> $str {
                if self.class-type.^lookup-by-str($str) -> $lookup {
                    SAST::Type.new(class-type => $lookup, match => self[0].match).do-stage2($ctx);
                } else {
                    self.make-new(SX, message => "'$str' is not a member of the {self.class-type.name} enum.").throw;
                }
            } else {
                self.make-new(SX, message => message => "Can't lookup a {self.class-type.name} with a runtime value").throw;
            }
        } else {
            self[0] .= do-stage2(self.type,:desc("didn't match primitive"));
            self;
        }

    }

    method compile-time { self[0].?compile-time }

    method gist { self.SAST::Type::gist ~  $.gist-children }
}

class SAST::Range is SAST::MutableChildren {
    has $.exclude-end;
    has $.exclude-start;
    method stage2($) {
        $_ .= do-stage2(tInt) for self.children;
        self;
    }

    method gist { $.node-name ~ "({'^' if $.exclude-start}..{'^' if $.exclude-end})" ~ $.gist-children }
    method type { tListp(tInt) }

    method itemize { False }
}

class SAST::ACCEPTS is SAST::MutableChildren {
    method type { tBool }
    method stage2($ctx) {
        if self[1] ~~ SAST::Type and not self[1].class-type.enum-type {
            $_ .= do-stage2(tAny) for @.children;
            self.stage2-node(
                SAST::BVal,
                val => so(self[0].ostensible-type ~~ self[1].class-type)
            );
        } else {
            SAST::MethodCall.new(
                self[1],
                name => 'ACCEPTS',
                pos => self[0],
                topic => self[0],
                :$.match,
            ).do-stage2($ctx);
        }
    }
}

class SAST::PRIMITIVE is SAST::MutableChildren {
    method type { tStr }
    method stage2($ctx) {
        self[0] .= do-stage2(tAny);
        my $type = self[0].ostensible-type;
        SAST::SVal.new(val => $type.primitive.name,:$.match).do-stage2(tStr);
    }
}

class SAST::WHAT is SAST::MutableChildren {
    method type { tStr }
    method stage2($) {
        self[0] .= do-stage2(tAny);
        my $type = self[0].ostensible-type;
        SAST::SVal.new(val => $type.name,:$.match).do-stage2(tStr);
    }
}

class SAST::WHY is SAST::MutableChildren {
    method type { tStr }

    method stage2($) {
        self[0] .= do-stage2(tAny);
        if self[0].?declaration -> {
            SAST::List.new(
                :$.match,
                |self[0].?declaration.docs.map({ SAST::SVal.new(val => .Str,match => .match)})
            ).do-stage2(tStr);
        } else {
            SX.new(message => "can't .WHY something that isn't declarable",:$.match).throw;
        }
    }
}

class SAST::NAME is SAST::MutableChildren {
    method type { tStr }

    method stage2($) {
        self[0] .= do-stage2(tAny);
        self;
    }
}

# For runtime args to eval
class SAST::EvalArg does SAST {
    has $.type is required;
    has Str $.placeholder is required;
    has SAST:D $.value is required;
}

class SAST::Eval is SAST::Children   {
    has %.opts;
    has SAST:D $.src is required;
    has SAST::Block:D $.outer is required;

    method stage2($) {
        $!src .= do-stage2(tStr);
        $_ .= do-stage2(tAny) for %!opts.values;
        self
    }

    method type { tStr }

    method children { $!src, |%!opts.values }
}

class SAST::Regex is SAST::Children is rw {
    has Str:D %.patterns;
    has SAST:D @.placeholders;
    has $.regex-type;

    method type {
        return tBool if $.ctx ~~ tBool;
        given $!regex-type {
            when  'case' { tPattern }
            default { tRegex }
        }
    }

    method stage2($ctx){
        $!regex-type = do given $ctx {
            when tPattern {
                %!patterns<case>:exists
                  or self.make-new(SX, message => "Unable to convert this regex to pattern").throw;
                'case'
            }
            default { 'ere'  }
        };
        if $ctx ~~ tBool {
            self.make-new(
                SAST::ACCEPTS,
                SAST::Var.new(sigil => '$',name => '_', :$.match),
                self
            ).do-stage2(tBool);
        } else {
            $_ .= do-stage2(tStr) for @!placeholders;
            self;
        }
    }

    method children { @!placeholders }

    method gist { $.node-name ~ "({%.patterns.gist})" ~ $.gist-children }
}

class SAST::Case is SAST::Children is rw {
    has SAST:D $.in is required;
    has SAST::Regex:D @.patterns;
    has SAST::Block:D @.blocks;
    has SAST $.default;

    # is created in stage3
    method children { $!in,|@!blocks,($!default // Empty) }

    method type { derive-common-parent (|@!blocks,$!default // Empty).map(*.type) }
}

class SAST::Quietly is SAST::Children {
    has SAST::Stmts:D $.block is required;

    method stage2($ctx) {
        $!block .= do-stage2($ctx,:!auto-inline);
        self;
    }

    method type { $!block.type }

    method children { $!block, }
}

class SAST::Start is SAST::Children {
    has SAST::Stmts:D $.block is required;

    method stage2($ctx) {
        $!block .= do-stage2(tAny,:!auto-inline);
        self;
    }

    method type { tPID }

    method children { $!block, }
}

class SAST::Doom does SAST {
    has SX $.exception is required;

    method type { tAny }
}

class SAST::Itemize is SAST::MutableChildren {
    has Sigil $.sigil;
    has Bool $.itemize;

    method itemize { $!itemize //= itemize-from-sigil($!sigil) }

    method stage2($ctx) {
        self[0] .= do-stage2(type-from-sigil($!sigil));
        self;
    }

    method gist { $.node-name ~ "({$!itemize ?? '$' !! '@'})" ~ $.gist-children }

    method type { self[0].type }
}

class SAST::OnBlock is SAST::Children does SAST::OSMutant {
    has @.os-candidates;
    has $.chosen-block is rw;
    has $!dispatcher;

    method stage2($ctx) {
        @!os-candidates .= map( -> $os, $block {
            cont-pair $os, $block.do-stage2($ctx)
        }).flat;
        self;
    }

    method mutate-for-os(Spit::Type $os) {
        $!chosen-block = $.dispatcher.get('anon', $os);
    }

    method dispatcher {
        $!dispatcher //= DispatchMap.new(anon => @.os-candidates).compose;
    }

    method children {
        ($!chosen-block // |@!os-candidates.map(*.value) || Empty),
    }

    method type {
        ($!chosen-block andthen .type) or
        derive-common-parent @!os-candidates.map(*.value.type);
    }
}

class SAST::LastExitStatus does SAST {
    method type { $.ctx ~~ tBool ?? tBool !! tInt }
}

class SAST::CurrentPID does SAST {
    method type { tPID }
}

class SAST::Die is SAST::Children {
    has SAST:D @.message;
    has SAST $.call;
    method stage2($) {
        $!call = SAST::SubCall.new(
            name => 'die',
            pos => @.message,
            :$.match,
        ).do-stage2(tAny);
        self;
    }

    method children { $!call, }
    method type { $.ctx }
}
