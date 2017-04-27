use Test;

plan 2;

ok HTTP<http://httpbin.org>.get.contains('httpbin(1)'),
    'GET http://httpbin.org';

ok HTTP<https://httpbin.org>.get
    .contains('httpbin(1)'), 'GET https://httpbin.org';
