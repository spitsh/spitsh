use Spit::Compile;

role Spit::Repo {

    method load(|c(:$repo-type,:$id!,:$debug)) {
        my $name = ($_ ~ '<' with $repo-type) ~ $id ~ ('>' if $repo-type);
        with self.resolve(|c) -> $src {
            compile($src,:target<stage2>,:$name,:$debug);
        }
    }
    proto method resolve(|) {*};
    multi method resolve(:$repo-type!,:$id!) { }
    multi method resolve(:$id!){ }

    method resolve-lib()  { }
}

class Spit::Repo::File does Spit::Repo {
    multi method resolve(:$repo-type!,:$id!) {
        if $repo-type eq 'file' {
            $id.IO.slurp
        }
    }

    method gist { self.^name }
}

class Spit::Repo::Core does Spit::Repo {
    sub get-core-module($id) {
        if $id eq 'Test' {
            %?RESOURCES{"core-lib/$id.spt"}.slurp;
        }
    }

    multi method resolve(:$repo-type!,:$id!) {
        if $repo-type eq 'core' {
            get-core-module($id) || die "No such core module '$id'";
        }

    }

    multi method resolve(:$id!) { get-core-module($id) }
}
