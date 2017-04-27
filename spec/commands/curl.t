use Test;

plan 5;


ok $*curl ~~ Cmd, 'curl is a Cmd';
ok $*curl.exists, 'referencing $*curl installs it';
ok ${ $*curl -V }.starts-with('curl 7.'), '--version seems work';

ok ${ $*curl -sL 'httpbin.org' }.contains('httpbin(1)'),
    'GET http://httpbin.org';

ok ${ $*curl -sL 'https://httpbin.org' }.contains('httpbin(1)'),
    'GET https://httpbin.org';
