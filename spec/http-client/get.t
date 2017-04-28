use Test;

plan 8;

ok HTTP<http://httpbin.org>.get.contains('httpbin(1)'),
    'GET http://httpbin.org';

ok HTTP<https://httpbin.org>.get.contains('httpbin(1)'),
    'GET https://httpbin.org';

{
    File.tmp(:dir).cd;
    my $get = HTTP<https://httpbin.org/get>.get-file;
    ok $get ~~ File, '.get-file returns a File';
    ok $get, '.get-file file exists';
    ok $get eq 'get', '.get-file has right default name';
    ok $get.contains('httpbin'), '.get-file content looks right';

    $get = HTTP<https://httpbin.org/get>.get-file(to => 'get.json');
    ok $get eq 'get.json','.get-file respects :to argument';
    ok $get.contains('httpbin'), '.get-file with :to content looks right'
}
