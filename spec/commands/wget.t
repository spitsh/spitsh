use Test;

plan 5;

ok $*wget ~~ Cmd, 'wget is a Cmd';
ok $*wget.exists, 'referencing $*wget installs it';
ok ${ $*wget -V }.starts-with('GNU Wget'), ‘It's the GNU version’;

ok ${ $*wget -qO- 'httpbin.org' }.contains('httpbin(1)'),
    'GET http://httpbin.org';

ok ${ $*wget -qO- 'https://httpbin.org' }.contains('httpbin(1)'),
    'GET https://httpbin.org';
