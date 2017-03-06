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

    method panic(Str:D $problem){ SX::Syntax.new(match => self.MATCH,:$problem).throw }
    method invalid(Str:D $problem){ SX::Syntax.new(match => self.MATCH,:$problem,:after).throw }
    method expected(Str:D $expected) { SX::Expected.new(:after,:marker-before-ws,match => self.MATCH,:$expected).throw }

}
