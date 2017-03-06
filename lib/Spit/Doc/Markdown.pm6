need Spit::SAST;
unit class Spit::Doc::Markdown;
need Spit::SpitDoc;
need Spit::Metamodel;

method gen-type-link($type) {
    return $type.name if $type.HOW ~~ Spit::Metamodel::Placeholder;
    my $path = $*PATH.parent.basename eq 'classes'
        ?? './' ~ $type.name
        !! '../' ~ $type.name;
        '[',$type.name,'](',$path,'.md)';
}


method heading($heading,&block) {
    my $*lvl = (CALLERS::<$*lvl> || 0) + 1;
    '#' x $*lvl,' ',|$heading,"\n",|&block();
}

method body(@spit,:$one-line) {
    return Empty unless @spit;
    my @prepend is default(Empty);
    flat do for @spit {
        when SpitDoc::Code {
            @prepend.push("\n");
            ("\n" if not $++),"```perl6",.txt.subst(/^\n*|[\n|\n*]$/,"\n",:g),"```";
        }
        when SpitDoc {
            ' ',|@prepend.shift,.txt,
        }
    }, ("\n" unless $one-line)
}
method block-quote(&block) {
    '>',|&block(),"\n"
}

method code(&block) {
    "```perl6\n",|&block(),"\n```"
}

method bold(&block) {
    '**',|&block(),'**'
}

method generate-dot-md(*@things,:$path,:$intro = '',:$*lvl = 0){
    my $*PATH = $path;
    join '',$intro, |@things.map({ self.doc($_) }).flat.grep(*.defined);
}


multi method doc(SAST::Var:D $_) {
    my $decl = do given .declaration {
        when SAST::ConstantDecl { 'constant'}
        default { 'variable' }
    }

    self.heading: .spit-gist, {
        self.block-quote: {
            $decl,' ',.spit-gist,
            (
                with .assign {
                    ' = ',
                    do if .compile-time ~~ any(*.so,*.defined) {
                        .spit-gist;
                    } else {
                        '...'
                    }
                }
            )
        };
        self.body(.docs);
    }
}

sub os-tree($enum-type,$tlvl is copy = 0) {
    my $link := ('[',$enum-type.name,'](#',$enum-type.name.lc,')');
    flat (' ' x ($tlvl++)*2 ),'* ',|$link,"\n",
    $enum-type.^children.map(*.&os-tree($tlvl)).flat;
}

method make-os-tree($top,:$*lvl = 0){
    self.heading: 'Operating System Taxonomy',{
        os-tree($top),"\n",
    };
}

multi method doc(SAST::ClassDeclaration:D $_ where *.class.enum-type) {
    self.heading: .name,{ self.body(.docs) }
}

multi method doc(SAST::ClassDeclaration:D $_) {

    my @parents = .class.^parents(:local).grep(*.so).map({ (',' if $++), self.gen-type-link($_) } ).flat;
    self.heading: .name, {
        self.body(.docs),
        do for .class.^spit-methods.sort(*.name) {
            self.doc($_);
        }
    };


}

multi method doc(SAST::RoutineDeclare:D $_) {

    self.heading: .name, {
        self.block-quote({
            .declarator,' ',.name,'(',self.doc(.signature),
            (' ⟶ ',self.gen-type-link(.return-type) if .return-type.name ne 'Any' ),')';
        }),
        "\n\n",
        self.body(.docs),
        self.param-list(.signature.children);
    }
}

method param-list(@params){
    if @params {
        "\n",
        '|Parameter|Description|',"\n",
        '|---------|-----------|',"\n",
        flat do for @params {
            '|',|self.bold({.spit-gist}),'|',|self.body(.docs,:one-line),'|',"\n";
        }

    }

}

multi method doc(SAST::Signature:D $_) {

    flat do for |.pos,|.named.sort».value {
        (', ' if $++),self.gen-type-link(.type),' ',self.bold({.spit-gist});
    },
}
