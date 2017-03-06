class SpitDoc {
    has $.match;
    has Str:D $.txt is required;

    method new(Str $txt? is copy,Match :$match is copy,|a) {
        if not $match {
            my $tmp = OUTER::CALLER::LEXICAL::<$/>;
            $match = $tmp // Nil;
        }
        $txt //= $match.Str;
        $txt ~~ s/\s+$//;
        self.bless(:$txt,:$match,|a);
    }

    method gist {
        "SpitDoc($!txt)"
    }

    method Str { $.txt }
}

class SpitDoc::Code is SpitDoc {
    has $.lang = 'spit';
    method gist {
        "SpitDoc::Code($.txt)";
    }
}
