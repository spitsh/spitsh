use Test;

plan 12;

{
    my $str = "FooD";
    is $str.subst-re(/[a-z]/, 'e'), 'FeoD', '.subst-re replaces first occurrence';
    is $str.subst-re(/[a-z]/, 'e', :g), 'FeeD', ':g replaces all occurrences';
    is $str.subst-re(/[a-z]/, 'e', :g, :i), 'eeee',
      ':g :i replaces all occurrences case insensitively';

    is $str.subst-re(/(o)/, '$1' ,:g), 'FooD', '$1';
    is $str.subst-re(/(o)/, ｢\$1｣ ,:g), 'F$1$1D', ｢\$1｣;
    is $str.subst-re(/(o)/, ｢\\$1｣,:g), ｢F\o\oD｣, ｢\\$1｣;
    #is $str.subst-re(/(o)/, ｢\\\$1｣,:g), ｢F\$1\$1D｣, ｢\\\$1｣;
    is $str.subst-re(/(o)/, ｢\\\\$1｣,:g), ｢F\\o\\oD｣, ｢\\\\$1｣;
    #is $str.subst-re(/(o)/, ｢\\\\\$1｣,:g), ｢F\\$1\\$1D｣, ｢\\\\\$1｣;
    is $str.subst-re(/(o)/, ｢\\\\\\$1｣,:g), ｢F\\\o\\\oD｣, ｢\\\\\\$1｣;
    #is $str.subst-re(/(o)/, ｢\\\\\\\$1｣,:g), ｢F\\\$1\\\$1D｣, ｢\\\\\\\$1｣;

    is $str.subst-re(/(F)/, '"' ,:g), '"ooD', '" in replacement';

}

{
    my $url = "https://irclog.perlgeek.de/perl6/2017-03-30";

    is $url.subst-re(rx‘^https’, 'ftp'), 'ftp://irclog.perlgeek.de/perl6/2017-03-30',
      'change http to ftp';
    is $url.subst-re(rx‘://(.+)\.(.+)\.([^/]+)/’, '://<subdomain:$1,hostname=$2.$3>/'),
      'https://<subdomain:irclog,hostname=perlgeek.de>/perl6/2017-03-30',
      '(.+)\.(.+)\.([^/]+)';
}

{
    my $text = "quick\nbrown\nfox";
    is $text.subst-re(/qui(ck\nb)rown/, 'qua$1londe'),
      "quack\nblonde\nfox", 'capture with newline';
}
