use Test;
plan 4;

my $repo = GitHubRepo<llfourn/rakudo>;
is $repo.owner, 'llfourn', '.owner';
is $repo.name,  'rakudo',  'rakudo';

is GitURL<https://github.com/llfourn/rakudo.git>.name, 'rakudo','GitURL.name';
is GitURL<https://github.com/llfourn/rakudo.git/>.name, 'rakudo',
    'GitURL.name ending in /';
