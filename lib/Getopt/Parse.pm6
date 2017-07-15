my constant UNDERLINE  = "\e[4m";
my constant ON_RED     = "\e[41m";
my constant RESET      = "\e[0m";
my constant GREEN      = "\e[32m";
my constant BOLD     = "\e[1m";
my constant BOLD_OFF = "\e[22m";
my constant BLINK    = "\e[5m";
my constant HEADING  = "\e[38;5;27m";
my constant COMMENT  = "\e[38;5;29m";

class Getopt::Parse::X::Missing {...}
class Getopt::Parse::X          {...}

#
sub opt( *%_ ( :$value-default,
               :$alias,
               :$name!,
               :$desc,
               :$long-desc,
               :$hint,
               :$required,
               :$match,
               :&on-use,
               :$placeholder,
               :$default,
               :$action,
             ) )  is export {
    with $alias { /^<:L>$/ || die "{$name}'s alias must be a single letter but got ‘$_’" };
    %_<match> //= 'bool';
    %_<required> //= False;
    $%_;
}

sub pos( *%_ (:$match, :$name!, :$required, :$usage, :$implicit-command) ) is export {
    %_<match> //= 'str';
    %_<required> //= True;
    $%_;
}

sub wrap-text($max-chars, $text) {
    my @lines;
    my int $len = 0;
    my $line = 0;
    for $text.words {
        if $len + .chars > $max-chars {
            $line++;
            $len = 0;
        }

        @lines[$line].push($_);
        $len += .chars;
    }
    @lines.map(*.join(' '));
}

sub pos-usage($_) {
    return '' unless .<usage>;
    "{@*command-path.map({“{UNDERLINE}{.<name>}{RESET}”}).join(' ')} <{.<name>}>\n  {.<usage>}";
}

grammar Getopt::Grammar {

    sub switch-command(@opts is raw, @pos is raw, @commands is raw, %res is raw,$command) {
        @opts.append: slip $command<opts> // Empty;
        @pos = slip $command<pos> // Empty;
        @commands = slip $command<commands> // Empty;
        @*command-path.push($command);
        %res<commands>.push($command<name>);
    }
    token TOP(:%command) {
        :my @opts = (|$_ with %command<opts>);
        :my @pos  = (|$_ with %command<pos>);
        :my @commands = (|$_ with %command<commands>);
        :my %res;
        (

            || [
                :my @opt;
                $<opt>=(
                    | '--' « [$<name>=<.identifier> ]
                    | '-'  « [$<alias>=<:L>]+
                )

                {
                    @opt = do given $<opt> {
                        with .<name> {
                            @opts.first(*.<name> eq .Str) //
                              self.exception("Unknown option: ‘{$<opt>.Str}’", match => $_);
                        }
                        orwith .<alias> {
                            .map: {
                                @opts.grep(*.<alias>.defined).first(*.<alias> eq .Str) //
                                self.exception("Unknown flag: ‘{.Str}’", match => $_);
                            }
                        }
                    };
                }
                [
                    || [
                        | '='
                          # Don't try and match the next argument if the opts
                          # are all just bool flags
                        | <?{ @opt.first({ .<match> ~~ Regex or .<match> !~~ 'bool'}) }>
                           <.sep> <!before '-'['-'|<:L>]> || <?before \d>
                       ]
                       <opt-value(@opt, %res)>
                    || <no-value(@opt, %res)>
                ]
            ]
            || [
                '--' [
                    || <.sep>
                       [ <str>+ % <.sep> ]
                       { %res<post-options> = $<str>.map(*.Str) }
                    || $
                ]
            ]
            || [
                $<command>=<.identifier>
                <?{
                    if @commands.first(*.<name> eq $<command>) -> $command {
                        switch-command(@opts, @pos, @commands, %res, $command);
                        True;
                    }
                }>
            ]
            || [
                <?{ @pos }>
                <pos-value(@pos[0], %res)>
                {
                    with @pos[0]<implicit-command> {
                        if @commands.first(*.<name> eq $_) -> $command {
                            switch-command(@opts, @pos, @commands, %res, $command);
                        }
                    }
                    @pos.shift;
                }
            ]
            || <bogus("Unknown argument")>

        )* % <.sep>
        {
            for @pos {
                self.missing(opt => $_, match => $/, usage => &*gen-usage()) if .<required>;
            }
            for @opts {
                if .<default>:exists and not %res{.<name>}:exists {
                    %res{.<name>} = do given .<default> {
                        when Callable { .(%res) }
                        default { $_ }
                    };
                }
            }
            $/.make: %res
        }
    }

    token identifier {
        <.ident> [ '-' <.ident> ]*
    }

    method check-value(Map:D $for, %res) {
        my $cursor := self.'!cursor_init'(self.orig(), :p(self.pos));

        my $*desc;
        my $new-cursor := do given $for<match> {
            when Regex { .($cursor)     }
            when Str   { $cursor."$_"() }
        };
        if $new-cursor.MATCH -> $match {

            my $orig = self.orig;
            if $orig.substr($new-cursor.pos ,1) eq "\x[1f]" or
            $new-cursor.pos == $orig.chars
            {
                my $val = $match.ast // $match.Str;
                with $for<on-use> {
                    .($val, %res);
                } else {
                    %res{$for<name>} = $val;
                }
                return $new-cursor;
            } else {
                self.invalid-value($for, wanted => $*desc);
            }
        } else {
            self.invalid-value($for, wanted => $*desc);
        }
    }

    method pos-value(Map:D $pos, %res) {
        self.check-value($pos, %res);
    }

    method opt-value(@opt, %res) {
        my $opt;
        my $*desc;
        if @opt == 1 {
            $opt = @opt[0];
        } else {
            for @opt {
                if .<match> ne 'bool' {
                    if not $opt {
                        $opt = $_;
                    } elsif .<value-default>:exists {
                        %res{.<name>} = .<value-default>;
                    }  else {
                        self.exception("Ambigious use of -{$opt.alias} with -{.alias} which both take a value");
                    }
                } else {
                    %res{.<name>} = True;
                }
            }
        }
        self.check-value($opt, %res);

    }

    method no-value(@opt, %res) {
        my $cursor := self.'!cursor_init'(self.orig(), :p(self.pos));

        for @opt -> $opt {
            my $val = do if $opt<value-default> -> $default {
                 $default;
            }
            elsif $opt<match> ~~ Regex or $opt<match> !~~ 'bool' {
                self.missing(:$opt, usage => $*PARSE.opt-usage($opt) );
            }
            else {
                True;
            }

            with $opt.<on-use> -> $on-use {
                $on-use.($val,%res)
            } else {
                %res{$opt<name>} = $val;
            }
        }

        /<?>/.($cursor);
    }

    token value-sep {
        '=' || <.sep>
    }

    method exception($message, :$usage = &*gen-usage(), :$match = self.MATCH){
        Getopt::Parse::X.new(
            :$message,
            command => $*PARSE.command<name>,
            :$match,
            :$*mark-invalid,
            :$usage,
        ).throw;
    }

    token bogus($what, :$usage) {
        <str>
        { self.exception: "$what: ‘{$<str>.Str}’", match => $<str> }
    }

    token invalid-value($opt, :$wanted) {
        <str>
        {
            self.exception(
                "Invalid value for {$opt<name>}."  ~ ($wanted andthen " Expected a $_ but got: ‘{$<str>.Str}’."),
                match => $<str>,
                usage => $*PARSE.usage(@*command-path),
            );
        }
    }

    method missing(:$opt, :$usage, :$match = self.MATCH) {
        Getopt::Parse::X::Missing.new(
            :$opt,
            :$match,
            command => $*PARSE.command<name>,
            :&*mark-missing,
            :$usage,
        ).throw;
    }

    token sep  { \x[1f] }

    token str {
        <-[\x[1f]]>+
    }

    token bool {
        <.desc("true/false value")>
        <?after '='> $<bool>=['false' || 'true'|| '0' || '1' || '']
        {
            $/.make: do given $/ {
                when !.defined  { True  }
                when 'true'|'1' { True  }
                default         { False }
            }
        }
    }

    token desc($thing) {
        { $*desc //= $thing } <?>
    }

    token int {
        <.desc("integer")>
        '-'?\d+
        { $/.make: $/.Str.Int }
    }

    token uint {
        <.desc("unsigned integer")>
        \d+
        { $/.make: $/.Str.Int }
    }

    token existing-file {
        <.desc("existing file")>
        <str>
        <?{ $/.Str.IO.f && $/.make: $/.Str.IO }>
    }

    token existing-directory {
        <.desc("existing directory")>
        <str>
        <?{ $/.Str.IO.d && $/.make: $/.Str.IO }>
    }

    token existing-path {
        <.desc("existing directory")>
        <str>
        <?{ $/.Str.IO.e && $/.make: $/.Str.IO }>
    }

    token path {
        <.desc("path")>
        <str>
        { $/.make: $/.Str.IO }
    }

    token word {
        <.identifier>
        { $/.make: $/.Str }
    }

}

class Getopt::Parse {
    has %.command is required;
    has $.pre-usage;
    has $.example;
    has $.grammar = Getopt::Grammar;
    has $.mark-invalid = ${ :before(ON_RED) , :after(RESET) };
    has Code $.mark-missing is rw;
    has %!usage-cache;
    has $.description-width = 60;
    has $.opt-width = 25;
    has $.opt-gap-width = 2;
    has $.opt-desc-width = 50;
    has $.left-margin = 2;
    has @.opt-color-alternate;

    method get-opts($args = @*ARGS) {
        my $str = $args.join("\x[1f]");
        my @*command-path = %.command,;
        my &*gen-usage = { self.usage(@*command-path) };
        $.mark-missing //= -> $opt {
            %( :after(BLINK ~ GREEN ~ " {$opt<hint> // “<$opt<name>>”}↩" ~ RESET) ),
        };
        my $*mark-invalid = $!mark-invalid;
        my &*mark-missing = &.mark-missing;
        my $*PARSE = self;
        $.grammar.parse($str,args => \(:%.command)).ast;
    }

    my $help = BEGIN %(
        name => 'help',
        match => 'bool',
        on-use => -> | {
            say &*gen-usage() and exit(0)
        },
        desc => 'Print help',
    );

    method TWEAK {
        %!command<name> //= $*PROGRAM-NAME;
        (%!command<opts> //= []);

        if not %!command<opts>.first(*.<name> eq 'help') {
            %!command<opts> = |%!command<opts>, $help;
        }
    }

    method gen-usage(@path = (%!command,)) {
        self.usage(@path);

        for |(@path[*-1]<commands> // ()) {
            self.gen-usage((|@path,$_));
        }

        self;
    }

    method usage(@command-path = (%!command,)) {
        my $path = @command-path.map(*.<name>).join('/');
        my $cache := %!usage-cache{$path};
        return $cache if $cache;

        my $command = @command-path[*-1];
        my @opts := $command<opts> // Empty;
        my @pos := $command<pos> // Empty;
        my @commands := $command<commands> // Empty;
        my @opt-colors = (flat lazy (@.opt-color-alternate xx ∞) if @.opt-color-alternate);
        $cache = join '',
        ($_ with $.pre-usage),

        HEADING ~ "Usage: " ~ RESET ~ @command-path.map({“{UNDERLINE}{.<name>}{RESET}”}).join(' '),

        (' <command>' if @commands),
        (' [<options>]' if @opts),

        |@pos.map({
            ' ',
            ('[' unless .<required>),
            '<',.<name>,'>',
            (']' unless .<required>)
        }).flat,
        "\n",

        ("\n{wrap-text($.description-width, $_).join(“\n”) ~ "\n"}" with $command<long-desc> // $command<desc>),

        |(
            @opts.map({
                "\n",
                (@opt-colors.shift if @opt-colors),
                self.opt-usage($_).indent($.left-margin),
                RESET
            }).flat,"\n" if @opts
        ),
        (
            if @commands {
                my $longest-cmd = @commands.map(*.<name>.chars).max;
                "\n{HEADING}Commands:{RESET}\n",
                @commands.map(
                    {
                        '  ',
                        .<name>,
                        ' ' x ($longest-cmd - .<name>.chars + 4),
                        ($_ with .<desc>),
                        "\n"
                    }
                ).flat
            }
        ),
        (with $command<example> {
             "\n{HEADING}Example:{RESET}\n",
             self.color-comment($_).indent($.left-margin),
        });

        $cache;
    }

    method opt-usage(Map:D $_) {
        my $total-width = $.opt-width + $.opt-gap-width + $.opt-desc-width;
        my $col1 = join '',
        ("-$_ " with .<alias> ),
        ("--{.<name>}"),
        (
            with .<placeholder> {
                " <$_>"
            }
            elsif .<match> ~~ Regex {
                " <value>"
            }
            elsif .<match> !~~ 'bool' {
                " <{.<match>.gist}>"
            }
            else {
                ''
            }
        );

        my $col2 = do with .<desc> -> $desc {
            if $col1.chars > $.opt-width  {
                "\n" ~ wrap-text($.opt-desc-width, $desc).
                join("\n").
                indent($.opt-width + $.opt-gap-width);
            }
            elsif $col1.chars + $desc.chars + $.opt-gap-width > $total-width  {
                my @wrapped = wrap-text($.opt-desc-width, $desc);
                @wrapped[0] ~ "\n" ~ @wrapped[1..*].join("\n").indent($.opt-width + $.opt-gap-width);
            }
            else {
                $desc;
            }
        }

        $col1 ~ (" " x ($.opt-width - $col1.chars + $.opt-gap-width)) ~  $col2;
    }

    method color-comment($_) {
        .subst(/'#' \N* $$/, {COMMENT ~ $/ ~ RESET }, :g);
    }
}


sub apply-markers($orig, @markers) {
    my @orig = $orig.comb;
    for @markers -> (:$before, :$after, :$from is copy, :$to is copy, :$match) {
        $from //= $match.from;
        $to   //= $match.to;
        if $before {
            @orig[$from] = $before ~ @orig[$from];
        }

        if $after {
            my $insert = $to - 1;
            $insert = 0 if $insert < 0;
            @orig[$insert] ~= $after
        }
    }
    @orig.join;
}

class Getopt::Parse::X is Exception is rw {
    has Match:D $.match is required;
    has $.message;
    has $.command;
    has $.usage;
    has $.mark-invalid;

    method gist {

        my $command-line =
          ('>> ' ~  $.command andthen "$_ ") ~
          ~ apply-markers($!match.orig.subst("\x[1f]"," ", :g), self.markers );

        "$.message\n$command-line" ~ ($.usage andthen "\n\n$_");
    }

    method markers {
        %( |$.mark-invalid, :$.match ),
    }
}

class Getopt::Parse::X::Missing is Getopt::Parse::X {
    has $.opt is required;
    has &.mark-missing is required;

    method message {
         "Value for ‘{$!opt<name>}’ is required.";
    }

    method markers {
        %( |&!mark-missing($.opt), :$.match ),
    }
}
