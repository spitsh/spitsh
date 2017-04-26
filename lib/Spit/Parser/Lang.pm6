need Spit::Exceptions;

grammar Spit::Lang {

    my %tweak-cache;

    method LANG($lang, $regex = 'TOP', *%args,:@tweaks) {

        my $actions    = self.slang_actions($lang);
        my $grammar    = self.slang_grammar($lang);

        if @tweaks {

            with %tweak-cache{"$lang+{@tweaks.join('+')}"} {
                $grammar = $_;
            } else {
                my @tweak-roles = @tweaks.map: { $grammar.get-tweak($_) };
                $_ = $grammar = $grammar.^mixin(|@tweak-roles);
            }
        }

        my $lang_cursor := $grammar.'!cursor_init'(self.orig(),:p(self.pos()), :shared(self.'!shared'()));
        $lang_cursor.clone_braid_from(self);

        $lang_cursor.set_actions($actions);
        $lang_cursor."$regex"(|%args);
    }

    method invalid(Str() $invalid){ SX::Invalid.new(match => self.MATCH,:$invalid).throw }
    method expected(Str:D $expected,$hint?) {
        SX::Expected.new(match => self.MATCH,:$expected,:$hint).throw
    }
    method panic(Str:D $panic) { SX.new(message => $panic, match => self.MATCH).throw }
    method NYI(Str:D $feature) { SX::NYI.new(:$feature, match => self.MATCH).throw }

    token spit-sigily {
        <?before '$'|'@'>
        [
            |$<sigily>=<.LANG('MAIN','var')>
            |$<sigily>=<.LANG('MAIN','cmd')>
        ]
        <index-accessor=.LANG('MAIN','index-accessor')>?
        {
            make do with $<index-accessor>.ast {
                .push($<sigily>.ast);
                $_;
            } else {
                $<sigily>.ast;
            }
        }
    }
}
