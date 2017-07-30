constant $:sed-delimiter = "\x[1e]";

#| The match list variable. Like `$/` in Perl 6 it stores the what was
#| match after a something is matched against a regex.
#|{
    my $text = "The file is: foo.txt";
    $text.match(/:\s*(.+)\.(.+)$/);
    say @/[0]; #-> : foo.txt
    say @/[1]; #-> foo
    say @/[2]; #-> txt
}
my @/;
#| The Str class is the base primitive class of Spit-sh. It represents
#| a string in the shell. Since all shell constructs are made out of
#| strings all types inherits from this class.
#|{
   say "foo" ~~ Str; # true
   say <one two three> ~~ Str; #true
}
augment Str {
    #| Writes string to `$:OUT` followed by a newline if it doesn't
    #| end in one already.
    method say { $self.${awk '{print}' >$:OUT} }
    #| Writes string to $:ERR followed by a newline if it doesn't end
    #| in one already.
    method note { $self.${awk '{print}' >$:ERR} }
    #| Writes string to `$:OUT`.
    method print { $self.${ >$:OUT } }
    #| Returns an uppercase version of the string
    method uc~    { $self.${tr '[:lower:]' '[:upper:]'} }
    #| Returns an lowercase version of the string
    method lc~    { $self.${tr '[:upper:]' '[:lower:]'} }
    #| Returns the number of characters in the string. **note:** This
    #| will depend on the locale of the terminal the script is running in.
    method chars+ { $self.${wc -m} }
    #| Returns the number of bytes in the string.
    method bytes+ { $self.${wc -c} }

    method lines+ { $self.${wc -l} }

    #| Splits the string on a separator. Returns the string with each
    #| instance of the `$sep` replaced with `\n` as a [List].
    method split(#|[The separator to split on]$sep)@ {
        $self.${
          awk -v "FS=$sep" '{l = split($0,a); for (i = 0; i < l;) print a[++i]}'
         }
    }
    #| Returns true if the string isn't empty
    method Bool { ${test $self} }

    #| Returns the string with the target string replaced by a replacement string.
    #| Does not modify the original string.
    #|{
       my $a = "food";
       $a.subst('o','e').say;
       $a.subst('o','e',:g).say;
       say $a;
    }
    method subst(#|[The string to be replaced]$target,
                  #|[The string to replace it with]$replacement,
                  #|[Turns on global matching]Bool :$g)~ {

        $self.${
            awk -v "g=$g" -v 'RS=^$' :T($target) :R($replacement)
            Q⟪
            {
                r=ENVIRON["R"]; t=ENVIRON["T"]
                while((g || !i) && (i = index(substr($0,w + 1),t))){
                    $0 = substr($0,1,i + w - 1) r substr($0,w + i + length(t));
                    if(length(t) > length(r)){
                        w += length(r) + i
                    }
                    else {
                        w += length(r) - length(t) + i;
                    }
                }
                print;
            }⟫
        }
    }

    method subst-eval($placeholder,$value)~ {
        $self.subst($placeholder,$value.subst("'","'\\''", :g), :g);
    }
    #| Returns true if the string contains `$needle`.
    #|{
       say "Hello, World".contains('Wo'); #-> True
       say "Hello, World".contains('wo'); #-> False
       say "Hello, World".contains('wo',:i); #-> True
    }
    method contains(#|[The string being searched for]$needle,
                     #|[Turns on case insensitive matching]Bool :$i)? on {
        Any {
            $self.${awk -v 'RS=^$' -v "t=$needle" -v "i=$i"
                    'END{exit(!index(i ? tolower($0) :$0, i ? tolower(t) : t))}'}
        }
        BusyBox {
            $self.${awk -v 'RS=^$' -v "t=$needle" -v "i=$i"
                    'END{exit(!index(i ? tolower($0) :$0, i ? tolower(t) : t))}'}
            # BusyBox returns false if needle is empty
            || !$needle
        }
    }

    #| Returns true if the string starts with the argument.
    #|{
        my @urls = <http://github.com ftp://ftp.FreeBSD.org>;
        for @urls {
            print "$_ is:";
            when .starts-with('http') { say "hyper text transfer" }
            when .starts-with('ftp')  { say "file transfer" }
            default { "well I'm not sure.." }
        }
    }
    method starts-with(#|[True if the string starts-with this]$starts-with)? {
        $self.${
            awk :T($starts-with) -v 'RS=^$'
            Q⟪{exit(index($0,ENVIRON["T"])!=1)}⟫
        }
    }

    #| Returns true if the string ends with the argument.
    #|{
        my @urls = <github.com ftp://ftp.FreeBSD.org>;
        for @urls {
            print "$_ might be: ";
            when .ends-with('.com') { say 'commercial' }
            when .ends-with('.org') { say 'an organisation' }
            when .ends-with('.io')  { say 'a moon of Jupiter' }
        }
    }
    method ends-with(#|[True if the string ends-with this]$ends-with)? {
        $self.${
            awk :T($ends-with) -v 'RS=^$' Q⟪{
                T=ENVIRON["T"]
                while (i = index(substr($0,w + 1),T)){
                    if(i = length($0)-length(T)+1)
                      exit 0
                    w = i
                }
                exit 1
            }⟫
        }
    }

    #| Returns true if the the string matches the regex and sets the
    #| `@/` match variable to the match and its capture groups (one per line).
    #|{
        my $regex = rx‘^(.+)://([^/]+)/?(.*)$’;
        if 'https://github.com/spitsh/spitsh'.match($regex) {
            say @/[0]; #-> https://github.com/spitsh/spitsh
            say @/[1]; #-> https
            say @/[2]; #-> github.com
            say @/[3]; #-> spitsh/spitsh
        }
    }
    method match(#|[The regular expression to match against]Regex $r)? is impure on {
        RHEL {
            @/ = $self.${
                awk :$r
                    # gawk match lets you pass an array which will get filled with
                    # all the matches
                    Q⟪{
                        if (match($0,ENVIRON["r"],a)){
                            i=0; while(a[i,"start"]) print a[i++]
                        } else {
                            exit 1;
                        }
                    }⟫
            };
            $?;
        }
        GNU {
            @/ = '';
            # note: GNU doesn't mean it has gawk
            if $self.matches($r) {
                @/ = {
                    my $i = 0;
                    $i++ while $self.${
                        sed -nr !>X
                        (
                            # slurp the input
                            'H;1h;$!d;x;' ~
                            # surround match with 0x1c
                            "s§$r§\\$i\\n§;" ~
                            # remove delims and print
                            's/^[^]*|[^]*$//gp'
                        )
                    };
                    ();
                };
                $?;
            }
        }
        BusyBox {
            @/ = "";
            if $self.matches($r) {
                @/ = {
                    my $i = 0;
                    $i++ while $i < 10 and $self.${
                        awk :$r -v 'RS=^$' -v "i=$i" q⟪
                            {
                                $0 = gensub(ENVIRON["r"], "§\\\\"i"§",1);
                                print gensub(/^[^§]*§|§[^§]*$/,"","G");
                            }⟫
                    };
                    ();
                }
                True;
            }
        }
    }

    #| Returns true if the string matches the regex and **doesn't**
    #| set or modify `@/` match variable.
    #|{
        my $regex = rx‘^(.+)://([^/]+)/?(.*)$’;
        my $url = 'https://github.com/spitsh/spitsh';
        if $url.match($regex) {
            my $host = @/[2];
            if $host.matches(/(www\.)?github.com/) {
                # @/ is preserved.
                my @user-repo = @/[3].split('/');
                say "The owner is @user-repo[0]. The repo is @user-repo[1]";
            } else {
                say "it's not github";
            }
        }
    }
    method matches(Regex $r)? on {
        Debian {
            # because mawk is the worst
            $self.${perl -e '(join "",<STDIN>) =~ /@ARGV[0]/s or exit 1' $r}
        }
        Any {
            $self.${
                awk :$r -v 'RS=^$'
                'END{if(!match($0,ENVIRON["r"])){ exit 1 }}'
            }
        }
    }

    method write-to(File $to)^ {
        $self.${awk -v "f=$to" -v 'RS=^$' '{printf "%s",$0>f;printf "%s",$0}'}
    }

    method append-to(File $to)^ {
        $self.${tee -a $to}
    }

    method extract-->File {
        $self.${ tar xvz | sed -n '1s/\/.*//p' };
    }
    method gist~ { $self }

    #| Returns True if the invocant and argument string are equal.
    method ACCEPTS($b)? { $b eq $self }

    method JSON {
        $self.${
            awk -v 'RS=^$' Q⟪
                END {
                    e="\\\\-\\\\-\n-\\n-\\\"-\\\"-\t-\\t-\\/-\\/-\r-\\r-\f-\\f-\b-\\b"
                    split(e,a,"-");
                    for (i = 1; i < 19; i += 2){
                        gsub(a[i],a[i+1])
                    }
                    printf "%s", "\"" $0 "\""
                }⟫
        }
    }

    # has to covert $1 to \1 and \$ to just $
    # XXX: WIP
    method subst-re(Regex $target, $replacement, Bool :$g, Bool :$i)~ on {
        Debian {
            $self.${
                perl -pe
                (
                    ‘use utf8;BEGIN{$/=undef};($t,$r)=(shift,shift);s/$t/$r/see’ ~
                    ($g && "g") ~ ($i && "i")
                )
                '--' '-' $target "qq§$replacement§"
            }
        }
        Any {
            $self.${
                awk -v 'RS=^$' -v "g={$g ?? 'g' !! '1'}" -v "IGNORECASE=$i"
                :T($target) :R($replacement) Q⟪
                END {
                    R = gensub(/([^\\]|^)((\\{2})*)\$([0-9&])/, "\\1\\2\\\\\\4", "g", ENVIRON["R"]);
                    R = gensub(/((\\*)\\)?\\[$]/,"\\2$","g",R);
                    R = gensub(ENVIRON["T"], R, g);
                    printf "%s", R
                }⟫
            }
        }
    }

    method substr(Int $start, Int $length?)~ {
        $self.${
            awk -v 'RS=^$' -v "s={$start + 1}" -v "l=$length"
            (
                '{printf "%s", substr($0,s' ~
                (~$length && ",l") ~
                ')}'
            )
        }
    }

    static method random($n = 10)~ {
        ${ tr -dc 'a-zA-Z0-9' < '/dev/urandom' | head -c $n }
    }

    method capture(Regex $regex)~ {
        $self.${sed -rn "s§$regex§\\1§;T;s/^.*//p;q"}
    }
}
