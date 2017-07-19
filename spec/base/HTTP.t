use Test; plan 5;

is HTTP<foo.com>.https, 'https://foo.com', '.https';
is HTTP<http://foo.com>.https, 'https://foo.com', '.https with http://';
is HTTP<https://foo.com>.https, 'https://foo.com', '.https with https://';
is HTTP<foo.com>.query(), 'foo.com', '.query()';
is HTTP<foo.com>.query( "foo" => "bar" ), 'foo.com?foo=bar', '.query( "foo" => "bar" )';
