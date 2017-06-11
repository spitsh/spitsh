use Test;

plan 3;

is HTTP<https://httpbin.org/post>.query( (foo => "bar") )
  .request('POST').json<args><foo>, 'bar',
  'query data';


is HTTP<https://httpbin.org/post>.query( (foo => "bar") )
  .request('POST', form => ( bar => '@foo') )
  .json<form><bar>, '@foo',
  'basic form data';

is HTTP<https://httpbin.org/headers>
  .request('GET', headers => 'Goof: GOOF')
  .json<headers><Goof>, 'GOOF', 'httpbin/org/headers';
