unit class Spit::Actions;
use Spit::SAST;
use Spit::Constants;
use Spit::Exceptions;
need Spit::Metamodel;

has $.outer;
has $.debug;

method e ($/) { make $<thing>.ast }

method TOP($/){
    $*CURPAD.append: ($<statementlist>.ast // ());
    my $tmp = $*CU;
    make $tmp;
}

method newpad($/) {
    my $new = SAST::Block.new;
    $new.outer = $_ with CALLERS::<$*CURPAD>;
    $*CURPAD = $new;
}

method finishpad($/){
    $*CURPAD .= outer;
}

method newCU($/) {
    if $*SETTING {
        $*CURPAD.outer = $!outer || $*SETTING;
    } else {
        $*SETTING = $*CURPAD;
    }
    $*CU = SAST::CompUnit.new(block => $*CURPAD,name => $*CU-name);
}

method statementlist($/) {
    make do if $<statement> {
        $<statement>.map(*.ast);
    } else {
        []
    }
}

method statement($/) {
    my $stmt = (.values[0].ast with $<statement>);
    make $stmt;
}

method EXPR-and-mod ($/) {
    my $expr = $<EXPR>.ast;
    my $*CURPAD = CALLERS::<$*CURPAD>;
    my $loop;

    with $<statement-mod-loop> {
        $loop = .ast;
        $loop.ann<statement-mod> = True;
        $loop.block = SAST::Block.new(outer => $*CURPAD);
    }

    with $<statement-mod-cond> {
        my $cond = .ast;
        $cond.ann<statement-mod> = True;
        if $loop {
            $cond.then = SAST::Block.new($expr,outer => $loop.block);
            $loop.block.push($cond);
            $expr = $loop;
        } else {
            $cond.then = SAST::Block.new($expr,outer => $*CURPAD);
            $expr = $cond;
        }
    } elsif $loop {
        $loop.block.push($expr);
        $expr = $loop;
    }

    make $expr;
}

method pragma:sym<use>($/) {
    my $spec = $<EXPR>.ast;
    my $match = $/; # BUG? $/ is being reset inside CATCH

    my %use = ($<identifier> andthen id => .Str)
    || (repo-type => $<repo-type>.Str,
        id => $<angle-quote>.ast.val);
    my $CU;

    for @*repos -> $repo {
        ($CU = $repo.load(|%use,:$.debug)) && last;
        CATCH {
            SX::ModuleLoad.new(
                :$repo,
                exception => $_,
                |%use,
                :$match,
            ).throw;
        }
    }
    if $CU {
        my @exported := $CU.exported;
        for SymbolType::.values -> $symbol-type {
            for @exported[$symbol-type].?values {
                $*CURPAD.declare($_);
            }
        }
    } else {
        SX::ModuleNotFound.new(|%use,:@*reps).throw;
    }
    make SAST::Empty.new;
}

method statement-prefix:sym<END> ($/) {
    make SAST::PhaserBlock.new(block => $<block>.ast,stage => Spit-Phaser::END );
}

method statement-prefix:sym<quietly> ($/) {
    make SAST::Quietly.new(block => $<block>.ast);
}

method statement-mod-cond:sym<if> ($/) {
    my $expr = $<EXPR>.ast;
    $expr = SAST::Neg.new($expr) if $<sym>.Str eq 'unless';
    make SAST::If.new(cond => $expr);
}

method statement-mod-loop:sym<for> ($/) {
    make SAST::For.new(list => $<list>.ast)
}

method statement-mod-loop:sym<while> ($/) {
    make SAST::While.new(cond => $<EXPR>.ast,until => $<sym> eq 'until');
}

method statement-control:sym<if> ($/) {
    my $expr =  $<EXPR>.ast;
    $expr = SAST::Neg.new($expr) if $<sym>.Str eq 'unless';
    my $topic-var = do with $<var-and-type>.ast {
        .dont-depend = True;
        $_;
    };
    my $if = SAST::If.new(
        cond => $expr,
        then => $<block>.ast,
        |(:$topic-var if $topic-var),
    );
    my SAST $prev-if = $if;

    for |$<elsif> {
        my $current-else = SAST::If.new(
            cond => .<EXPR>.ast,
            then => .<block>.ast,
        );
        $prev-if.else = $current-else;
        $prev-if = $current-else;
    }
    with $<else> {
        $prev-if.else = .ast;
    }
    make $if;
}

method statement-control:sym<for> ($/) {
    my $iter-var = do with $<var-and-type> {
        my $var = .ast;
        $var.dont-depend = True;
        $var;
    };
    make SAST::For.new(
        list => $<list>.ast,
        block => $<block>.ast,
        |(:$iter-var if $iter-var),
    );
}

method statement-control:sym<while> ($/) {
    my $topic-var = do with $<var-and-type> {
        my $var = .ast;
        $var.dont-depend = True;
        $var;
    };
    make SAST::While.new(
        until => ($<sym>.Str eq 'until'),
        cond => $<EXPR>.ast,
        block => $<block>.ast,
        |(:$topic-var if $topic-var),
    );
}

method statement-control:sym<given> ($/) {
    make SAST::Given.new(
        block => $<block>.ast,
        given => $<EXPR>.ast,
    );
}

method statement-control:sym<when> ($/) {
    my ($if,$last,$this);
    for $/[0] {
        $this = SAST::If.new(
            cond => ($_<EXPR> andthen .ast or SAST::BVal.new(val => True,match => $_<block>)),
            then => $_<block>.ast,
            :when,
        );
        $if //= $this;
        $last.else = $this if $last and $last ~~ SAST::If;
        $last = $this;
    }
    make $if;
}

method statement-control:sym<on> ($/) {
    make SAST::OnBlock.new: os-candidates => $<on-switch>.ast;
}

sub declare-new-type($/,$name,\MetaType) {
    my $type := MetaType.new_type(:$name);
    my $CLASS := SAST::ClassDeclaration.new(class => $type);
    $type.^set-declaration($CLASS);
    $*CLASS = $*CURPAD.declare: $CLASS;
    $*CU.export: CLASS,$name,$CLASS;
    $CLASS;
}

sub set-primitive(Mu $type is raw) {
    if $type.^primitive =:= Mu {
        if $*CURPAD.lookup(CLASS,'Str') -> $str {
            $type.^add_parent($str.class);
        }
    }
    $type
}

method declaration:sym<class> ($/){
    my $class =  $<new-class>.ast;
    set-primitive($class.class);
    $class.class.^compose;
    $class.block = $<blockoid>.ast;
    make $class;
}

method declare-class-params ($/) {
    for $*CLASS.class.^placeholder-params -> $type {
        $*CURPAD.declare: SAST::ClassDeclaration.new(class => $type);
    }
}

method new-class ($/) {
    my $class = declare-new-type($/,$<type-name>.Str,Spit::Metamodel::Type);
    with $<class-params><params><thing> {
        for $_<type-name>.map(*.Str).kv -> $i,$name {
            my $placeholder-type := Spit::Metamodel::Placeholder.new_type(:$name);
            set-primitive($placeholder-type);
            $placeholder-type.^set-param-of($class.class,$i);
            $placeholder-type.^compose;
            $class.class.^placeholder-params.push($placeholder-type);
        }
    }
    make $class;
}

method class-params ($/) {
    make cache  $<params><thing><type-name>.map: {
        $*CURPAD.lookup(CLASS,.Str,match => $_);
    };
}

method declaration:sym<augment> ($/) {
    my $class := $<old-class>.ast.class;
    $class.^compose;
    make SAST::ClassDeclaration.new(block => $<blockoid>.ast,:$class);
}

method old-class ($/) {
    my $name = $<type-name>.Str;
    my $decl = $*CURPAD.lookup(CLASS,$name,match => $/);
    $*CLASS = $decl;
    make $decl;
}

method declaration:sym<enum-class> ($/) {
    my $enum-class =  $<new-enum-class>.ast;
    unless $enum-class.class.^parents {
        if $*CURPAD.lookup(CLASS,'EnumClass') -> $enum-class-base {
            $enum-class.class.^add_parent($enum-class-base.class);
            $enum-class.class.^set-primitive($enum-class.class);
        }
    }
    $enum-class.class.^compose;
    $/.make: $enum-class;
}

method new-enum-class ($/) {
    make declare-new-type($/,$<type-name>.Str,Spit::Metamodel::EnumClass);
}

method trait:sym<is> ($/){
    if $<primitive> {
        $*CLASS.class.^set-primitive($*CLASS.class);
    } elsif $<native> {
        $*ROUTINE.is-native = True;
    } elsif $<export> {
        $*CU.export($*DECL);
    } elsif $<rw> {
        $*ROUTINE.rw  = True;
    } elsif $<impure> {
        $*ROUTINE.impure = True;
    } else {
        $*CLASS.class.^add_parent($<type>.ast);
    }
}

method declaration:sym<sub> ($/) {
    make $*CURPAD.declare: $<routine-declaration>.ast;
}

method declaration:sym<method> ($/) {
    my $method := $<routine-declaration>.ast;
    $method.invocant-type = $*CLASS;
    make $*CLASS.class.^add-spit-method: $method;
}



method routine-declaration ($/) {

    given $*ROUTINE -> $r {
        $r.os-candidates =  $<on-switch>.ast || (tOS(), $<blockoid>.ast);
        make $r;
    }
}

method new-routine($/) {
    my (:@pos,:%named) := $<param-def>.ast<paramlist>.ast;
    my $r = $*ROUTINE;
    $r.signature = SAST::Signature.new(:@pos,:%named);
    $r.return-type = .ast with $<param-def>.ast<return-type> || $<return-type-sigil>;
    make $r;
}

method make-routine ($/,$type,:$static) {
    my $name = $<name>.Str;
    $*ROUTINE = do given $type {
        when 'sub' { SAST::SubDeclare.new(:$name) }
        when 'method'  {
            SX.new(message => 'methdod declared outside of a class').throw unless $*CLASS;
            my $r = SAST::MethodDeclare.new(:$name,:$static);
            unless $static {
                for <$ @> {
                    $r.invocants.push: $*CURPAD.declare: SAST::Invocant.new(sigil => $_,class-type => $*CLASS.class);
                }
            }
            $r;
        }
    };
}

method on-switch ($/) {
    # XXX: BUG in rakudo. Value from seq disappears so assign to array first.
    my @tmp = $/<candidates>.ast[0].map({  $_<os>.ast, $_<block>.ast }).flat;
    make @tmp;
}

method declaration:var ($/) {
    my $var = $<var-and-type>.ast;
    $var.assign = $<statement>.ast;
    make $*CURPAD.declare: $var;
}

method return-type-sigil:sym<~>($/) { make tStr() }
method return-type-sigil:sym<+>($/) { make tInt() }
method return-type-sigil:sym<?>($/) { make tBool() }
method return-type-sigil:sym<@>($/) { make tList() }

method paramlist ($/) {
    my @params = $<params>.map(*<param>.ast);

    my %paramlist := Map.new:
       (pos => @params.grep(SAST::PosParam)),
       (named => @params.grep(SAST::NamedParam).map({ .name => $_ }).Map);


    make %paramlist;
}

method param ($/) {
    make $*CURPAD.declare: do if $<pos> {
        SAST::PosParam.new(
            name => $<var><name>.Str,
            sigil => $<var><sigil>.Str,
            |(type => .ast with $<type>),
            slurpy => ?$<slurpy>.Str
        )
    } else {
        SAST::NamedParam.new(
            name => $<var><name>.Str,
            sigil => $<var><sigil>.Str,
            |(type => .ast with $<type>),
        )
    }
}

method EXPR($/) {
    my @infixes = $<infix> || ();
    my SAST:D @terms = $<termish>.map: -> $term {
        #CATCH {  }
        my $res := $term.ast;
        SX.new(message => 'internal error while compiling this node ' ~ $term.gist, match => $term).throw
           unless $res ~~ SAST:D;
        $res;
    };

    while @infixes {
        for ^@infixes -> $i {
            my $this = @infixes[$i];
            my $next = @infixes[$i+1];
            my ($precedence,$assoc) = $this.&derive-precedence(@terms[$i]);
            my $next-precedence = $next.&derive-precedence(@terms[$i+1])[0];
            my $cmp = $assoc == LEFT ?? &infix:«ge» !! &infix:«gt»;

            if $cmp($precedence,$next-precedence) {
                my $infix-sast = $this.ast;
                # Some infix might not be as simple as appending the terms to the
                # SAST node. So we allow it to return a callable which will be called
                # with the terms.
                if $infix-sast ~~ Callable {
                    $infix-sast = $infix-sast(|@terms.splice($i,2));
                    @terms.splice($i,0,$infix-sast);
                } else {
                    $infix-sast.append: @terms.splice($i,2,$infix-sast);
                }
                @infixes.splice($i,1);
                last;
            }
        }
    }
    make @terms[0];
}

method list ($/) {
    my $list = SAST::List.new;
    for $<EXPR> {
        $list.push(.ast);
    }
    make $list;
}
sub reduce-term(Match:D $term,@prefixes,@postfixes) {
    my $ret = $term.ast;
    for |@postfixes,|@prefixes.reverse {
        my $ast = .ast;
        if $ast ~~ Callable {
            $ret = $ast.($ret);
        } else {
            $ast.push($ret);
            $ret = $ast;
        }
    }
    $ret
}
method termish($/) {
    make reduce-term($<term>,$<prefix>,$<postfix>);
}

method term:true  ($/) { make SAST::BVal.new(val => True) }
method term:false ($/) { make SAST::BVal.new(val => False) }

method term:my ($/) {
    make $*CURPAD.declare: $<var-and-type>.ast;
}

method var-create($/,$decl-type) {
    my \ast-type = do given $decl-type {
        when 'constant'  { SAST::ConstantDecl }
        when 'my'        { SAST::VarDecl }
        when 'topic'     { SAST::MaybeReplace }
    };
    make ast-type.new(
        name => $<var><name>.Str,
        sigil => $<var><sigil>.Str,
        |(decl-type => .ast with $<type>),
        match => $/,
    );
}

method term:block ($/) { make $<block>.ast }
method term:quote ($/)   { make $<quote>.ast  }
method term:angle-quote ($/) { make $<angle-quote>.ast }
method term:int ($/)   { make $<int>.ast    }
method int ($/) { make SAST::IVal.new: val => $/.Int }
method term:var ($/)   { make $<var>.ast }

method var ($/)   {
    make SAST::Var.new(
        name => $<name>.Str,
        sigil => $<sigil>.Str,
    );
}

method term:special-var ($/) { make $<special-var>.ast }
method special-var:sym<$?> ($/) { make SAST::LastExitStatus.new }

method term:name ($/) {
    my $name = $<name>.Str;
    make do if $<is-type> {
        my @params = $<class-params>.ast || Empty;
        do with $<object> {
            if $_<angle-quote> andthen (my $list = .ast) ~~ SAST::List {
                for $list.children {
                    $_ = SAST::Blessed.new(
                        class-name => $name,
                        :@params,
                        $_,
                        match => .match,
                    );
                }
                $list;
            } else {
                my $definite = $list || $_<EXPR>.ast;
                SAST::Blessed.new(
                    class-name => $name,
                    :@params,
                    $definite,
                )
            }
        } else {
            SAST::Type.new(
                class-name => $name,
                :@params,
            )
        }
    } else {
        my (:@pos,:%named) := $<call-args><args>.ast || Empty;
        SAST::SubCall.new(:$name,:@pos,:%named);
    }
}



method term:sast ($/) {
    my (:@pos,:%named) := $<args>.ast;
    make ::('SAST::' ~ $<identifier>.Str).new(|@pos,|%named);
}

method term:parens ($/) {
    my @stmts = $<statementlist>.ast;
    make do if not @stmts {
        SAST::Empty.new;
    } elsif @stmts == 1 {
        @stmts[0];
    } else {
        SAST::Stmts.new(|@stmts)
    }
}

method term:cmd ($/) {
    make $<cmd>.ast;
}

sub gen-method-call($/) {
    my (:@pos,:%named) := $<args>.ast;
    my $name = $<name>.Str;
    given $name {
        when 'WHAT' { return SAST::WHAT.new }
        when 'WHY'  { return SAST::WHY.new }
        when 'PRIMITIVE' { return SAST::PRIMITIVE.new }
        when 'NAME' { return SAST::NAME.new }
    }

    SAST::MethodCall.new(
        :$name,
        :@pos,
        :%named,
    );
}

method term:topic-call ($/) {
    my $call = gen-method-call($/);
    $call.push: SAST::Var.new(name => '_',sigil => '$');
    make $call;
}

method term:topic-cast ($/) {
    make SAST::Cast.new(to => $<type>.ast,SAST::Var.new(name => '_',sigil => '$'));
}

method term:pair ($/) {
    my ($key,$value);
    if $<var> {
        $key = $<var><name><identifier>;
        $value = $<var>.ast;
    } else {
        $key = $<key>;
        if $<value> {
            $value = $<value>.ast;
        } else {
            $value = SAST::BVal.new(val => True);
        }
    }
    $key = SAST::SVal.new(val => $key.Str,match => $key);
    make SAST::Pair.new(:$key,:$value);
}

method term:fatarrow ($/) {
    make SAST::Pair.new( key => SAST::SVal.new(val => $<key>.Str), value => $<value>.ast);
}

method eq-infix:sym<&&> ($/)  { make SAST::Junction.new }
method eq-infix:sym<||> ($/)  { make SAST::Junction.new(:dis) }
method eq-infix:sym<and> ($/) { make SAST::Junction.new }
method eq-infix:sym<or> ($/)  { make SAST::Junction.new(:dis) }
method eq-infix:sym<~> ($/)   { make SAST::Concat.new() }
method eq-infix:intexpr ($/)  { make SAST::IntExpr.new(sym => $<sym>.Str) }

method infix:eq-infix ($/) { make $<sym>.ast }
method infix:sym<=> ($/) {
    make -> $var,$val {
        if $var ~~ SAST::Assignable && $var.assign-type {
            $var.assign = $val;
            $<eq-infix> andthen $var.assign-mod = .ast;
        } else {
            SX::Assignment-Readonly.new.throw;
        }
        $var;
    }
}
method infix:sym<.=> ($/) {
    make -> $var,$_ {
        unless $var ~~ SAST::Assignable && $var.assign-type {
            SX::Assignment-Readonly.new.throw
        }
        when SAST::Call {
            $var.assign = .make-new(
                SAST::MethodCall,
                :name(.name),
                :named(.named),
                :pos(.pos),
                $var.gen-reference(match => $var.match),
            );
            $var;
        }
        when SAST::Cmd {
            proceed if .pipe-in;
            .pipe-in = $var.gen-reference(match => $var.match);
            $var.assign = $_;
            $var;
        }
        default {
            SX::Invalid.new(invalid => 'RHS for ‘.=’').throw;
        }
    }
}
method infix:sym<,>  ($/) {
    make -> $lhs,$rhs {
        if $lhs ~~ SAST::List && $rhs !~~ SAST::List {
            $lhs.push($rhs);
            $lhs;
        } else {
            SAST::List.new($lhs,$rhs);
        }
    }
}

method infix:sym<~~> ($/) { make SAST::ACCEPTS.new }

method infix:comparison ($/) { make SAST::Cmp.new(sym => $<sym>.Str)  }

method infix:sym<..> ($/) {
    make SAST::Range.new(
        :$<exclude-start>,
        :$<exclude-end>,
    );
}

method infix:sym<?? !!> ($/) {
    my $on-true = $<EXPR>.ast;
    make -> $cond,$on-false {
        SAST::Ternary.new(
            :$cond,
            :$on-false,
            :$on-true
        );
    }
}

method postfix:method-call ($/) {
    make gen-method-call($/);
}

method args ($/,|) {
    my $list = $<list>.ast;
    make {
        pos => $list.children.grep({ $_ !~~ SAST::Pair}).list,
        named => $list.children.grep(SAST::Pair).map({.key.val => .value}).Hash;
    }
}

method postfix:cmd-call ($/) {
    my $first = $<cmd>.ast;
    my $last = $first;
    $last = $last.pipe-in while $last.pipe-in;
    make -> $called-on {
        $last.pipe-in = $called-on;
        $first;
    };
}

method postfix:sym<++> ($/)  { make SAST::Increment.new }
method postfix:sym<--> ($/)  { make SAST::Increment.new(:decrement) }
method postfix:sym<[ ]> ($/) { make $<index-accessor>.ast }
method postfix:sym<⟶> ($/) { make SAST::Cast.new(to => $<type>.ast) }

method index-accessor($/) { make SAST::Elem.new(index => $<EXPR>.ast) }

method prefix:sym<~> ($/) { make SAST::Coerce.new(to => tStr()) }
method prefix:sym<+> ($/) { make SAST::Coerce.new(to => tInt()) }
method prefix:sym<-> ($/) { make SAST::Negative.new() }
method prefix:sym<?> ($/) { make SAST::Coerce.new(to => tBool())}
method prefix:sym<!> ($/) { make SAST::Neg.new() }
method prefix:sym<++> ($/) { make SAST::Increment.new(:pre) }
method prefix:sym<--> ($/) { make SAST::Increment.new(:pre,:decrement) }
method prefix:sym<^>  ($/) { make SAST::Range.new(SAST::IVal.new(val => 0),:exclude-end) }
method prefix:i-sigil ($/) {
    make do given $<sigil>.Str {
        when '$'|'@' { SAST::Itemize.new(sigil => $_) }
        default { die "invalid itemizing sigil: $_" }
    }
}
method prefix:sym<@>  ($/) { make SAST::Itemize(sigil => $<sym>.Str) }

method pblock($/) {
    if $<lambda> {
        make $<blockoid>.ast;
    } else {
        make $<block>.ast;
    }
}

method blockoid($/) {
    my $pad = $*CURPAD;
    $pad.append($<statementlist>.ast);
    make $pad;
}


method block($/)    {
    make $<blockoid>.ast
}

method type ($/) {
    with $<class-params>.ast {
        make SAST::Type.new( params => $_,class-name => $<type-name>.Str ).class-type;
    } else {
        make $*CURPAD.lookup(CLASS,$/<type-name>.Str,match => $<type-name>).class;
    }
}
method os   ($/) { make $*CURPAD.lookup(CLASS,$/.Str,match => $/).class }

method cmd ($/) { make $<cmd-pipe-chain>.ast }

method cmd-pipe-chain ($/) {
    my $cmd;
    for $<cmd-body>.map(*.ast) -> $next {
        $next.pipe-in = $cmd with $cmd;
        $cmd = $next;
    }
    make $cmd;
}

method cmd-body ($/) {
    my (SAST:D @pos,SAST:D %set-env,SAST:D @write,SAST:D @append,SAST:D @in);
    for $<cmd-arg> {
        with $_<cmd-term> {
            @pos.push: .ast;
        }
        orwith $_<bare> {
            @pos.push: SAST::SVal.new(val => .Str);
        }
        orwith $_<parens> {
            @pos.push: .ast
        }
        orwith $_<pair>.ast {
            %set-env{.key.compile-time} = .value;
        }
        orwith $_<redirection> {
            my (@add-write,@add-append,@add-in) := .ast;
            @write.append(@add-write);
            @append.append(@add-append);
            @in.append(@add-in);
        }
    }

    make SAST::Cmd.new(|@pos,:%set-env,:@write,:@append,:@in);
}

method cmd-term ($/) {
    make reduce-term($/[0].values[0],$<i-sigil>,$<postfix>);
}


method redirection($/) {
    my &make-fd =  { SAST::Blessed.new(class-name => 'FD',SAST::IVal.new(val => $_),match => $/) }
    my $src = $<src>;
    my @src-fd = (
        ($src<all> andthen (make-fd(1),make-fd(2)))
        or $src<fd> andthen .ast
        or ($src<err> && make-fd(2))
        or ($<in> ?? make-fd(0) !! make-fd(1) )
    );

    my $dst = $<dst>;
    my $gen-dst = $dst<null>
    ?? { $*SETTING.lookup(SCALAR,'*NULL').gen-reference(match => $dst<null>)  }
    !! $dst<cap>
    ?? { $*SETTING.lookup(SCALAR,'?CAP').gen-reference(match => $dst<cap>)    }
    !! $dst<err>
    ?? { $*SETTING.lookup(SCALAR,'*ERR').gen-reference(match => $dst<err>) }
    !! { $dst<fd>.ast.deep-clone };

    my (@write,@append,@in);
    for @src-fd -> $src-fd {
        if $<write> {
            @write.append: $src-fd,$gen-dst();
        } elsif $<append> {
            @append.append: $src-fd,$gen-dst();
        } else {
            @in.append: $src-fd,$gen-dst();
        }
    }
    make (@write,@append,@in);
}

sub make-quote($/) { make $<str>.ast andthen .match = $/ }
method quote:double-quote       ($/) { make-quote($/) }
method quote:curly-double-quote ($/) { make-quote($/) }
method quote:single-quote       ($/) { make-quote($/) }
method quote:curly-single-quote ($/) { make-quote($/) }
method quote:sym<qq>            ($/) { make-quote($/) }
method quote:sym<q>             ($/) { make-quote($/) }
method balanced-quote           ($/) { make-quote($/) }
method quote:regex        ($/) { make SAST::Regex.new(src => $<str>.ast) andthen .match = $/; }


method angle-quote ($/) {
    my $val = $<str>.Str;
    my SAST::CompileTimeVal @parts = $val.split(" ").map: {
        do if try .Int ~~ Int {
            SAST::IVal.new(val => .Int);
        } else {
            SAST::SVal.new(val => $_);
        }
    };
    make do if @parts > 1 {
        SAST::List.new(|@parts);
    } else {
        @parts[0];
    }
}
method quote:sym<eval> ($/) {
    my $src = $<balanced-quote>.ast;
    my %opts = $<args>.ast.<named> || Empty;
    make SAST::Eval.new(:%opts,:$src,outer => $*CURPAD);
}

method wrap ($/) {
    with $<thing><R> {
        make .ast;
    } else {
        make $<thing>;
    }
}

method r-wrap ($/) { self.wrap($/)}
