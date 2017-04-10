use Spit::Compile;
use Spit::PRECOMP;
need Spit::SAST;
need Spit::Exceptions;

role Spit::Repo {

    method load(|c(:$repo-type,:$id!,:$debug)) {
        my $name = ($_ ~ '<' with $repo-type) ~ $id ~ ('>' if $repo-type);
        with self.resolve(|c) {
            when Str { compile($_,:target<stage2>,:$name,:$debug) }
            when SAST::CompUnit {
                proceed unless .stage2-done;
                $_;
            }
            default {
                SX::Bug.new(
                    desc => "{self.gist} returned an invalid SAST::CompUnit ({.gist})" ~
                    " while trying to load '$name'";
                ).throw;
            }
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
        %core-lib{$id} andthen .return;
    }

    multi method resolve(:$repo-type!,:$id!) {
        if $repo-type eq 'core' {
            get-core-module($id);
        }

    }

    multi method resolve(:$id!) { get-core-module($id) }
}
