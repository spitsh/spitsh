use Test;

plan 4;

given DockerImg<foo:bar> {
    is .tag, 'bar', '.name';
    is .name, 'foo', '.tag';
}

given DockerImg<fedora/httpd:version1.0> {
    is .tag, 'version1.0','.tag # version1.0';
    is .name, 'fedora/httpd', '.name # fedora/http';
}
