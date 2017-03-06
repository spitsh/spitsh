use lib 'lib';
use Spit::SETTING;
use Spit::Constants;
need Spit::Doc::Markdown;


sub MAIN(|) {
    my \SDM = Spit::Doc::Markdown;
    {
        my $dir = "doc/classes/".IO;
        $dir.mkdir;
        for $SETTING.symbols[CLASS].values.grep(!*.class.enum-type) -> $class {
            my $path = $dir.child($class.name ~ '.md');
            $path.spurt: SDM.generate-dot-md($class,:$path) if $class.docs;
        };
    }

    {
        my $path = "doc/subs.md".IO;
        $path.spurt:
          SDM.generate-dot-md($SETTING.symbols[SUB].values.sort(*.name),:$path);
    }

    {
        my $path = "doc/variables.md".IO;
        $path.spurt:
           SDM.generate-dot-md($SETTING.symbols[SCALAR,ARRAY]».values.flat,:$path);

    }

    {
        my $path = "doc/operating-systems.md".IO;
        my \UNIXish = $SETTING.lookup(CLASS,'UNIXish').class;
        my $intro = join '', "doc-staging/os-intro.md".IO.slurp,SDM.make-os-tree(UNIXish,:lvl(2));
        $path.spurt:
            SDM.generate-dot-md(
                :$intro,
                :$path,
                :lvl(2),
                $SETTING.symbols[CLASS].values.grep({ .class ~~ UNIXish }).sort(*.name),
            );
    }
}
