use Test;

my $httpbin = 'https://httpbin.org';

{
    plan 21;
    my $resp = HTTP("$httpbin/bytes/42").request('GET');
    ok $resp.is-success, '.is-success';
    ok $resp.code == 200, 'code is 200';
    is $resp.message, 'OK', '.message is OK';
    ok $resp.body.bytes == 42, '.body.bytes is right';
    ok $resp.body-size == 42, '.body-size is the same';
    is $resp.req-headers.host, 'httpbin.org', '.req-headers.host';
    is $resp.http-version, '1.1', '.http-version';
}

{
    my $resp = HTTP("$httpbin/encoding/utf8").request('GET');
    is $resp.charset, 'UTF-8', '.charset UTF-8';
}

{
    my $resp = HTTP("$httpbin/gzip").request('GET');
    is $resp.headers.content-encoding, 'gzip', '.content-encoding gzip';
}

{
    my $resp = HTTP("$httpbin/status/400").request('GET');
    nok $resp.is-success, '400 !.is-success';
    ok $resp.is-error, '400 .is-error';
    nok $resp.is-server-error, '400 !.is-server-error';
    ok  $resp.is-client-error, '400 .is-client-error';
    is $resp.message, 'BAD REQUEST', '400 .message';
}

{
    my $resp = HTTP("$httpbin/redirect/1").request('GET');
    ok $resp.is-redirect, '302 .is-redirect';
    is $resp.headers.location, "/get", '.headers.location';
}

{
    my $resp = HTTP("$httpbin/relative-redirect/2").request('GET', :max-redirects(1));
    ok $resp.is-redirect, 'redirected to a redirect .is-redirect';
    is $resp.remote-url, "$httpbin/relative-redirect/1",
      ':max-redirects(1) stops after 1';
}

{
    my $to = File.tmp;
    my $resp = HTTP("$httpbin").request('GET', :$to);
    is $resp<body>, $to, ':to';
}

{
    my $resp = HTTP("$httpbin/headers").request: 'GET', headers => ("Foo: bar", "Bar: baz");
    is $resp.req-headers<Foo>, 'bar', 'first header';
    is $resp.req-headers<Bar>, 'baz', 'second header';
}
